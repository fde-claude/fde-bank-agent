# Runbook — Steps 11 to 14

Execution guide for Module 4 on the cluster and the state-layer steps. Steps 12–14 are appended as they are delivered.
Run everything from the repository root (`bank-agent/`). `[OPS]` = platform work, `[DEV]` = Python changes.

---

## Step 11 — The gateway on Kubernetes `[OPS]`

### What changes and why

Until now the gateway ran in Compose and the cluster's app still called Anthropic directly with the provider key.
After this step the cluster looks like production:

- **A second Helm chart, `deploy/chart/litellm/`**, built like the app chart: the LiteLLM proxy (2 replicas), its
  Postgres (a StatefulSet with a PersistentVolumeClaim) and its Redis, all in a namespace of their own, `litellm`.
- **One configuration file for two runtimes.** `config.yaml` moved into the chart (`deploy/chart/litellm/files/`).
  Compose mounts it from there; the chart renders the same file into a ConfigMap. Edit one file, both runtimes follow.
- **The provider key has exactly one home**: the Secret `litellm-secrets` in the `litellm` namespace. The app's Secret
  `bank-agent-secrets` now holds a *virtual key* issued by the gateway: revocable, budgeted, rate-limited.
- **The app chart's ConfigMap** gains `ANTHROPIC_BASE_URL` (the gateway's in-cluster DNS name), `MODEL_ID: bank-primary`
  (an alias; the gateway decides Haiku or Opus) and `SDK_MAX_RETRIES: "0"` (the gateway owns retries and fallback).
- **Two replicas behave as one gateway** because the gateway is stateless: keys, budgets and spend live in Postgres;
  rate-limit counters and cooldowns live in Redis. Kill a replica and nothing is lost.
- **Different security posture per namespace, on purpose.** The app namespace enforces the `restricted` Pod Security
  profile. The upstream LiteLLM image picks its own user and writes at startup, so the `litellm` namespace enforces
  `baseline` and the chart carries two *documented* exceptions (annotations with a reason). A hardened rebuild of
  the image is tracked for Module 6, where Kyverno starts enforcing.

### 11.1 Get the files

```bash
bash ~/Downloads/step11-files.sh        # 17 files; also removes the old deploy/litellm/config.yaml (it moved into the chart)
find deploy/chart/litellm -type f | sort
```

### 11.2 Namespace and the gateway's Secret

```bash
kubectl create namespace litellm
kubectl label namespace litellm pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/warn=restricted
set -a; source .env; set +a
PGPASS=$(openssl rand -hex 16)
kubectl -n litellm create secret generic litellm-secrets \
  --from-literal=ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  --from-literal=LITELLM_MASTER_KEY="$LITELLM_MASTER_KEY" \
  --from-literal=LITELLM_SALT_KEY="$LITELLM_SALT_KEY" \
  --from-literal=UI_USERNAME="${UI_USERNAME:-admin}" \
  --from-literal=UI_PASSWORD="$UI_PASSWORD" \
  --from-literal=POSTGRES_PASSWORD="$PGPASS" \
  --from-literal=DATABASE_URL="postgresql://litellm:$PGPASS@litellm-postgres:5432/litellm"
```

What each key is for: `ANTHROPIC_API_KEY` is the provider key, consumed only by the gateway. `LITELLM_MASTER_KEY` is the
gateway's admin credential (API and UI login fallback). `LITELLM_SALT_KEY` encrypts credentials the gateway stores in its
database; set once, never rotate. `POSTGRES_PASSWORD` is read by the Postgres container; `DATABASE_URL` is the same
password in URL form, read by the proxy. The host `litellm-postgres` is the headless Service the chart creates, which
is why the release must be named `litellm`.

`warn=restricted` means the API server tells you which fields *would* fail the strict profile without blocking the pod.
Free advice for the Module 6 rebuild.

### 11.3 Install the gateway

```bash
helm upgrade --install litellm deploy/chart/litellm -n litellm -f deploy/chart/litellm/values-dev.yaml
kubectl -n litellm get pods -w
```

Expected order: `litellm-postgres-0` becomes Ready once its volume is bound, `litellm-redis-…` is quick, then the two
`litellm-…` proxy pods take one to two minutes: the first start runs database migrations, which is why the chart has
a long startup probe (60 × 2 s) before liveness applies.

```bash
kubectl -n litellm get pvc,svc,pdb
kubectl -n litellm logs deploy/litellm | grep -iE "set models|running on"      # bank-primary, bank-fallback
```

Look at the PVC: `data-litellm-postgres-0`, Bound, 1Gi. That volume is the Tier-0 state of the model path.

### 11.4 Issue the app's virtual key on the cluster gateway

The cluster gateway has its own database, so the key you made in Compose does not exist here. Two ways; do both once.

**UI** (if the Compose gateway still holds local port 4000, forward to 4001):

```bash
kubectl -n litellm port-forward svc/litellm 4001:4000
```

`http://localhost:4001/ui` → sign in → Teams: `bank-agent-dev` (5 USD / 30 d) → Virtual Keys: `bank-agent-k8s`, team
`bank-agent-dev`, models `bank-primary`, 2 USD / 30 d, RPM 60. Copy it once: `export VKEY=sk-...`.

**API**, the way CI will do it in Step 17 for its own budget-capped key:

```bash
curl -s http://localhost:4001/key/generate -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H 'content-type: application/json' \
  -d '{"key_alias":"bank-agent-k8s-api","models":["bank-primary"],"max_budget":2,"budget_duration":"30d","rpm_limit":60}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['key'])"
```

Keys are data: created at runtime, by UI or API, never committed. Only the *policy* (which budgets exist) is yours to
document.

### 11.5 Swap the app's Secret and roll the app

```bash
kubectl -n bank-agent delete secret bank-agent-secrets
kubectl -n bank-agent create secret generic bank-agent-secrets --from-literal=ANTHROPIC_API_KEY="$VKEY"
helm upgrade bank-agent deploy/chart/bank-agent -n bank-agent -f deploy/chart/bank-agent/values-dev.yaml
kubectl -n bank-agent rollout status deploy/bank-agent
kubectl -n bank-agent exec deploy/bank-agent -- env | grep -E "ANTHROPIC_BASE_URL|MODEL_ID|SDK_MAX_RETRIES"
kubectl -n bank-agent exec deploy/bank-agent -- env | grep -c "sk-ant-"      # 0: the provider key is gone from the app namespace
```

Why the pods rolled: the ConfigMap changed, so the `checksum/config` annotation changed. Note the limit of that trick:
the Secret is not rendered by the chart, so a *secret-only* change does not roll pods. For that, `kubectl -n bank-agent
rollout restart deploy/bank-agent`.

### 11.6 Verify the whole chain through the edge

```bash
JWT_SECRET=$(kubectl -n bank-agent get secret bank-client-jwt -o jsonpath='{.data.secret}' | base64 -d)
TOKEN=$(JWT_KEY=bank-client JWT_SECRET=$JWT_SECRET ./scripts/mint-jwt.sh)
RID=$(curl -si -X POST http://localhost/chat -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' \
      -d '{"message":"What is the balance on ACC-1001?"}' | tee /dev/stderr | grep -i '^x-request-id:' | awk '{print $2}' | tr -d '\r')
echo "request id: $RID"
kubectl -n bank-agent logs -l app.kubernetes.io/name=bank-agent --tail=20 | grep "$RID"
```

Then in the cluster gateway UI → Logs → filter by trace id `$RID`: two rows (tool call, then answer), tag `bank-agent`,
model `bank-primary` resolved to Haiku, key alias `bank-agent-k8s`. One ID, four hops: client → APISIX → app → gateway.

### 11.7 Drills

**Gateway HA.** In one terminal run a loop; in another delete one proxy pod.

```bash
for i in $(seq 1 30); do curl -s -o /dev/null -w "%{http_code} " -X POST http://localhost/chat -H "Authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' -d '{"message":"hi"}'; sleep 1; done
# other terminal:
kubectl -n litellm delete pod -l app.kubernetes.io/component=proxy --field-selector=status.phase=Running --wait=false | head -1
kubectl -n litellm get pods -w
```

Expected: all 200s (a 502 or two at most while the Service drops the dying pod), the Deployment replaces the pod, the
PDB kept one proxy up throughout. Note the APISIX consumer limit: 10 per minute, so run this with the mobile-app key or
raise the limit for the drill.

**Shared state across replicas.** Create a key with `rpm_limit: 2`, send three requests through the gateway
(port-forward, Bearer that key). The third is 429 even though two different pods may have served the first two: the
counter lives in Redis, not in a pod.

**Fallback on the cluster.**

```bash
curl -s http://localhost:4001/v1/chat/completions -H "Authorization: Bearer $VKEY" -H 'content-type: application/json' \
  -d '{"model":"bank-primary","mock_testing_fallbacks":true,"messages":[{"role":"user","content":"Which model are you?"}]}' | head -c 200
```

UI Logs: `bank-fallback` (Opus) answered. The app would never know.

**Config change rolls the gateway.** Edit `deploy/chart/litellm/files/config.yaml`, `request_timeout: 120` → `90`, then
`helm upgrade --install litellm deploy/chart/litellm -n litellm -f deploy/chart/litellm/values-dev.yaml` → both proxy
pods roll (checksum). Compose would pick up the same edit on its next `up -d`. Revert and roll again.

**Postgres survives its pod.**

```bash
kubectl -n litellm delete pod litellm-postgres-0 --wait=false; kubectl -n litellm get pods -w
```

The StatefulSet recreates the pod, it reattaches the same PVC, and `$VKEY` still works afterwards: the keys were on
disk, not in the pod. (Deleting the PVC would be the total outage; don't.)

**Backup and restore, the Tier-0 drill.**

```bash
mkdir -p backups
kubectl -n litellm exec litellm-postgres-0 -- pg_dump -U litellm litellm > backups/litellm-$(date +%F).sql
ls -la backups/
# prove the dump restores, into a scratch database on the same instance
kubectl -n litellm exec litellm-postgres-0 -- createdb -U litellm litellm_restore
kubectl -n litellm exec -i litellm-postgres-0 -- psql -q -U litellm litellm_restore < backups/litellm-$(date +%F).sql
kubectl -n litellm exec litellm-postgres-0 -- psql -U litellm litellm_restore -tAc 'select count(*) from "LiteLLM_VerificationToken";'   # your keys, counted
kubectl -n litellm exec litellm-postgres-0 -- dropdb -U litellm litellm_restore
echo "backups/" >> .gitignore
```

What this teaches: the gateway database is derived from nothing; lose it and every key, team and budget is gone and
every agent gets 401 at once. In production this is a managed Postgres with point-in-time recovery, or an operator
such as CloudNativePG with WAL archiving to object storage, a tested restore, and a written RPO/RTO. The drill is the
same `pg_dump`/`psql` pair; only the automation changes.

### 11.8 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| proxy pods restart or never Ready | DB unreachable, migration still running, weak master key | `kubectl -n litellm logs deploy/litellm`; `DATABASE_URL` host must be `litellm-postgres`; wait out the startup probe |
| `litellm-postgres-0` Pending | PVC cannot bind | `kubectl get storageclass` (Docker Desktop: `hostpath` default); `kubectl -n litellm describe pvc` |
| pods rejected on create | namespace enforces `restricted` | label the namespace `baseline` as in 11.2 |
| app returns 502, log says 401 | wrong or blocked virtual key | `kubectl -n bank-agent get secret bank-agent-secrets -o jsonpath='{.data.ANTHROPIC_API_KEY}' \| base64 -d`; key status in the UI |
| app returns 502, log says connection error | base URL unreachable | `kubectl -n bank-agent exec deploy/bank-agent -- python -c "import urllib.request;print(urllib.request.urlopen('http://litellm.litellm.svc:4000/health/liveliness').status)"` |
| UI on 4000 shows the Compose gateway | port clash | forward to 4001 as in 11.4, or `docker compose stop litellm` |
| gateway Logs page empty | spend logging disabled or wrong gateway | you are looking at the Compose UI; use the port-forwarded cluster UI |

### 11.9 Done when

- Two proxy pods, Postgres and Redis Running in `litellm`; the PVC is Bound.
- The app pods carry the gateway URL and the alias, and no `sk-ant-` value exists in the app namespace.
- One request ID is visible in the APISIX response header, the app log and the gateway Logs page.
- A proxy pod was deleted under load with no outage; a backup was taken and restored into a scratch database.

### Compose still works

Compose mounts the config from its new location (`deploy/chart/litellm/files/config.yaml`). `docker compose up -d`
picks it up. The two environments now differ only in where secrets come from.

### Commit

```bash
git add -A && git status                          # .env and backups/ must not appear
git commit -m "Step 11: LiteLLM gateway on Kubernetes, app routed through the in-cluster gateway"
```

### Next: Step 12 `[DEV]`

Slices 3–5: two more tools (`get_recent_transactions`, `request_cheque_book`), Redis conversation memory with a sliding
window, and the system prompt and model alias moved out of code into `prompts/` and the ConfigMap. The first time the
app itself becomes stateful, and the first time a prompt change is a config rollout.
