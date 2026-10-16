# Runbook — Steps 15 to 19

Execution guide for the observability module and Module 5 (CI/CD and GitOps). Steps 16–19 are appended as delivered.
Run everything from the repository root (`bank-agent/`). `[OPS]` = platform work, `[DEV]` = Python changes.

---

## Step 15 — Observability: traces, GenAI metrics, dashboard, alerts `[OPS]` + `[DEV]` (~40 lines)

### What changes and why

Step 8 gave you the three HTTP metrics: traffic, latency, errors. They tell you *that* the service is unhealthy. This
step adds the three things that tell you *why*, for an LLM service specifically.

- **Traces, end to end.** The gateway already records every model call it proxies. Now it sends each one to **Langfuse**
  (free Cloud tier) as an observation with model, tokens, cost, latency, key alias, tag, and the trace and session ids from
  our headers. The app sends its own spans to the same Langfuse project over OpenTelemetry: one span per HTTP request
  (FastAPI instrumentation), one `agent.run` span, one `gen_ai.chat` span per model call with the OpenTelemetry GenAI
  attributes (model, input and output tokens, finish reason), and one span per tool call. Open a request in Langfuse and
  you see the whole tree: how many turns, which tools, how long each model call took, what it cost.
- **GenAI metrics in Prometheus** (`agent.py`): model calls by stop reason, tokens by kind (input, output, cache read,
  cache creation), turns per request, tool calls by outcome, loop-guard trips, knowledge-base searches by confidence. The
  token counters come from the provider's usage block in each response, so the app can measure cache effectiveness and
  token throughput without depending on the gateway's metrics.
- **A dashboard as code** (`deploy/monitoring/dashboards/bank-agent-genai.yaml`): eleven panels in a ConfigMap that
  Grafana's sidecar loads automatically. Edit in the UI, export, paste back, commit.
- **Alert rules as code** (`deploy/chart/bank-agent/templates/prometheusrule.yaml`): nine rules shipped with the app
  chart, loaded by the Prometheus Operator. Availability (no ready pods, scrape down, error ratio, p95 latency) and
  GenAI-specific (loop guard, tool error rate, output ceiling hits, knowledge gap, cold prompt cache). Module 7 turns
  the first group into SLOs with error budgets.
- **Tracing is optional and zero-cost when off.** `telemetry.py` becomes a no-op unless Langfuse keys (or a generic OTLP
  endpoint) are configured, so the CLI and the tests run unchanged.
- **The session id now travels to the gateway too** (`x-litellm-session-id`), so a whole conversation groups together in
  the gateway logs and in Langfuse. The Step 1 loop is still untouched; spans and counters wrap around it.

What this does **not** do: the gateway's own Prometheus `/metrics` endpoint is gated behind LiteLLM's enterprise licence
in recent versions. We do not depend on it: cost per key and per model come from Langfuse and the gateway UI, tokens
come from the app's counters.

### 15.1 Langfuse project (5 min, UI)

- Sign up at `https://cloud.langfuse.com` (EU) or `https://us.cloud.langfuse.com`, free tier. Create an organisation and a
  project named `bank-agent`.
- Project → Settings → API Keys → Create: copy the public key (`pk-lf-…`) and secret key (`sk-lf-…`).
- One project for the gateway's records and the app's spans: they share trace ids, so they land on the same traces.

### 15.2 Get the files, release 0.7.0

```bash
bash ~/Downloads/step15-files.sh
cat >> .env << 'EOF2'
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
LANGFUSE_HOST=https://cloud.langfuse.com
EOF2
OWNER=<your-owner> VERSION=0.7.0 ./scripts/release.sh
```

### 15.3 Compose: traces in Langfuse

```bash
docker compose up -d --build                          # gateway restarts with the Langfuse callbacks; agent 0.7.0 with tracing
docker compose logs litellm | grep -i langfuse        # callback initialised, no auth errors
S=cust-$(openssl rand -hex 3)
chat() { curl -s -X POST localhost:8000/chat -H 'content-type: application/json' -d "{\"message\":\"$1\",\"session_id\":\"$S\"}"; echo; }
chat "My account is ACC-1001."
chat "What is my balance and what are the fees for a replacement card?"   # tool + knowledge base in one turn
```

Langfuse → Tracing → Traces: the second request. Expected tree: `POST /chat` → `agent.run` (attributes `request.id`,
`session.id`) → `gen_ai.chat` (turn 1, finish reason `tool_use`, tokens) → `tool get_account_balance`, `tool
search_bank_faq` → `gen_ai.chat` (turn 2, `end_turn`). Next to it, the gateway's generations for the same trace id with
cost and the key alias. Sessions view: the whole conversation under `$S`.

Lesson: the app knows the shape of the work (turns, tools), the gateway knows the money (cost per call, which model
actually answered). Same trace id joins them; neither side alone tells the story.

### 15.4 Kubernetes: metrics, dashboard, alerts

```bash
# Secrets gain the Langfuse keys (gateway and app); namespaces unchanged
kubectl -n litellm patch secret litellm-secrets -p "{\"stringData\":{\"LANGFUSE_PUBLIC_KEY\":\"$LANGFUSE_PUBLIC_KEY\",\"LANGFUSE_SECRET_KEY\":\"$LANGFUSE_SECRET_KEY\",\"LANGFUSE_HOST\":\"$LANGFUSE_HOST\"}}"
kubectl -n bank-agent patch secret bank-agent-secrets -p "{\"stringData\":{\"LANGFUSE_PUBLIC_KEY\":\"$LANGFUSE_PUBLIC_KEY\",\"LANGFUSE_SECRET_KEY\":\"$LANGFUSE_SECRET_KEY\"}}"
helm upgrade --install litellm deploy/chart/litellm -n litellm -f deploy/chart/litellm/values-dev.yaml   # config checksum changed (callbacks): proxy rolls
kubectl -n litellm rollout restart deploy/litellm      # the Secret change alone would not have rolled it; the config change did, this is belt and braces
helm upgrade bank-agent deploy/chart/bank-agent -n bank-agent -f deploy/chart/bank-agent/values-dev.yaml
kubectl -n bank-agent rollout status deploy/bank-agent
kubectl -n bank-agent get prometheusrule                # bank-agent, 9 rules
kubectl apply -f deploy/monitoring/dashboards/bank-agent-genai.yaml
```

- Grafana (`localhost:3000`) → Dashboards → "bank-agent · GenAI service": eleven panels. Send a few requests through APISIX
  and watch "Model calls / s by stop reason" and "Tokens / min by kind" move; after two or three repeated questions the
  "Prompt cache hit ratio" climbs.
- Prometheus (`localhost:9090`) → Status → Rules: group `bank-agent.availability` and `bank-agent.genai`, all green.
  Alerts → nothing firing.

### 15.5 Drills

**Make an alert fire.** `kubectl -n bank-agent scale deploy/bank-agent --replicas=0` (with autoscaling on, delete the
ScaledObject first or scale the HPA's min: `kubectl -n bank-agent patch scaledobject bank-agent --type merge -p
'{"spec":{"minReplicaCount":0}}'`), wait 2 minutes: `BankAgentNoReadyPods` goes pending then firing in Prometheus →
Alerts, and Alertmanager (`kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-alertmanager 9093:9093`,
`localhost:9093`) shows it. Restore `minReplicaCount: 2`.

**Loop guard alert.** Temporarily set `MAX_TURNS = 1` in the Compose agent? Simpler: ask something that needs two tools and
a follow-up in one message with `MAX_TURNS` lowered to 1 via a quick edit, rebuild, send one request: the answer is the
"Sorry…" fallback, `agent_loop_guard_total` increments, `BankAgentLoopGuardTripped` fires within the next evaluation.
Revert. In Langfuse the trace shows exactly one `gen_ai.chat` and no final answer: the shape of a runaway loop.

**Trace a failure.** Block the virtual key in the gateway UI, send one request: the app's `POST /chat` span is marked
error (502), the `gen_ai.chat` span records the exception, the gateway's failure callback logs a failed generation with
the 401. Unblock. Three views of one failure, joined by the trace id.

**Cache cold alert.** Change one word in `prompts/system.md`, rebuild, send traffic: the first calls show
`cache_creation` tokens, the hit ratio dips, then recovers as the new prefix warms. `BankAgentPromptCacheCold` is an
`info` alert with a one-hour window, so it only fires if the ratio stays low: a changed prompt once is fine, a prompt
that changes per request is a cost bug.

**Dashboard round-trip.** Change a panel in Grafana (e.g. add a threshold line at 20 s on p95), Dashboard settings →
JSON model → copy → replace the JSON in `deploy/monitoring/dashboards/bank-agent-genai.yaml` → `kubectl apply` → reload
Grafana: your change survived because it lives in git now.

### 15.6 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| no traces from the app in Langfuse | keys missing in the app's environment | `docker compose exec agent env \| grep LANGFUSE`; both keys must be present |
| gateway logs `langfuse` auth errors | wrong keys or wrong region host | match `LANGFUSE_HOST` to where the project was created (EU vs US) |
| app spans and gateway generations on different traces | trace id not forwarded | check `x-litellm-trace-id` in gateway Logs; `agent.py` `gateway_headers` |
| dashboard missing in Grafana | sidecar not watching the namespace, or label missing | ConfigMap must carry `grafana_dashboard: "1"`; `deploy/monitoring/values.yaml` sets `searchNamespace: ALL` |
| rules not loaded | selector | `ruleSelectorNilUsesHelmValues: false` in monitoring values; `kubectl -n monitoring get prometheus -o yaml \| grep ruleSelector` |
| `helm upgrade` fails on `PrometheusRule` | CRD missing | kube-prometheus-stack installed? (Step 8) |
| panels show "No data" | no traffic yet, or metric names changed | send requests; `curl localhost:8080/metrics \| grep agent_` after a port-forward |

### 15.7 Done when

- A `/chat` request appears in Langfuse as one trace with the app's span tree and the gateway's generations.
- The GenAI dashboard shows live data; the nine rules are loaded and green; one alert was made to fire and clear.
- `deploy/monitoring/dashboards/` is committed and applied; a UI edit round-tripped through git.

### Commit

```bash
git add -A && git commit -m "Step 15: Langfuse traces, OpenTelemetry spans, GenAI metrics, dashboard and alert rules as code"
```

### Next: Step 16

See below.

---

## Step 16 — CI: lint, test, scan, sign, push `[OPS]`

### What changes and why

Until now every check ran by hand: ruff and hadolint on my side, Trivy and Cosign through `release.sh` on yours. This
step makes the checks a gate that no change can skip, and it does so with the March 2026 LiteLLM compromise as the
template of what a pipeline must not do: that attack started with a poisoned scanner Action running inside a CI job
with access to publishing tokens.

- **`.github/workflows/ci.yaml`**, five jobs. `lint` (ruff, hadolint), `test` (pytest with a fake model and a real
  pgvector service container), `secrets` (gitleaks over the full history), `manifests` (helm lint, kube-linter), and
  `build` which needs the other four and does build → Trivy gate → push → keyless sign → SBOM → attestation → verify.
  Pull requests run everything except the push; `main` publishes.
- **Five rules the file follows, each visible in it.** Every Action pinned to a full commit SHA (the `# vN` comment is
  for humans and Dependabot). Scanners downloaded as release binaries and verified against the publisher's checksums
  (hadolint has no checksum file, so its hash is pinned directly). `GITHUB_TOKEN` is read-only by default and widened per
  job: only `build` may write packages and mint an OIDC token. Signing is keyless: the workflow's identity is the
  signature, verifiable by anyone with no key material. One run per branch; superseded PR runs are cancelled.
- **`tests/`**: the offline checks from Steps 1–15 become a permanent suite (29 tests). `conftest.py` scripts the model
  and replaces Redis; nothing touches the network. Two tests need Postgres with pgvector and skip themselves when there
  is none; CI provides one as a service container, so they run on every pull request.
- **`pyproject.toml`**: ruff and pytest settings; the same commands work locally. `ruff format` reformatted the six
  Python files (whitespace only, no logic). From now on, formatting is enforced, not discussed.
- **`.gitleaks.toml`**: default rules plus an allow-list for documented placeholders (`.env.example`, `REPLACE_ME`,
  the runbooks' key shapes). **`.kube-linter.yaml`**: the lab's single-replica stores are exempt from the anti-affinity check.
- **`.github/dependabot.yml`**: pinned versions rot unless something proposes updates. Dependabot opens weekly pull
  requests for Actions (it understands SHA pins), pip pins and the Dockerfile base image, and every proposal runs this
  pipeline, plus the eval gate from Step 17, before a human merges.

### 16.1 Get the files, run the checks locally first

```bash
bash ~/Downloads/step16-files.sh
pip install ruff==0.17.1 pytest==9.1.1
ruff check . && ruff format --check .                              # clean
pytest                                                             # 27 passed, 2 skipped (no database here)
docker run --rm -d --name kdb -e POSTGRES_USER=knowledge -e POSTGRES_PASSWORD=ci -e POSTGRES_DB=knowledge -p 55432:5432 pgvector/pgvector:pg16
KNOWLEDGE_DATABASE_URL=postgresql://knowledge:ci@localhost:55432/knowledge ANTHROPIC_BASE_URL=http://unused.invalid pytest   # 29 passed
docker rm -f kdb
```

Everything CI runs, you can run. That is the point of putting configuration in `pyproject.toml` instead of the workflow.

### 16.2 Push and watch the first run

```bash
git add -A && git commit -m "Step 16: CI pipeline with pinned actions, checksummed scanners, keyless signing"
git push
```

GitHub → Actions → `ci`: four jobs in parallel (lint, test, secrets, manifests), then `build`. On `main` the build pushes
`ghcr.io/<owner>/bank-agent:sha-<7 chars>` and `:<full sha>`, signs the digest, attaches the SBOM, verifies both, and
writes the digest into the run's summary.

Things to open while it runs:

- `test` job: the `knowledge-db` service container starting, then `29 passed`.
- `build` job: the Trivy table. Fixed HIGH/CRITICAL findings fail the job; unfixed base-image findings appear in the
  uploaded `trivy-report` artifact without blocking. That is the policy from Step 3, now enforced.
- The run summary: the published digest.

### 16.3 Verify the signature from your laptop, with nothing but the public internet

```bash
DIGEST=ghcr.io/<owner>/bank-agent@sha256:<from the run summary>
cosign verify "$DIGEST" \
  --certificate-identity-regexp "^https://github.com/<owner>/bank-agent/.github/workflows/ci.yaml@refs/heads/main$" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com | head -c 600
cosign verify-attestation "$DIGEST" --type spdxjson \
  --certificate-identity-regexp "^https://github.com/<owner>/bank-agent/.github/workflows/ci.yaml@refs/heads/main$" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com | head -c 300
```

The certificate inside the signature says: this image was built by *this workflow file*, on *this branch*, in *this
repository*. No key was stored anywhere; the `cosign.key` from Step 4 is now only for local experiments.

### 16.4 Drills: make the gate refuse things

**A leaked secret.** On a branch, add a file containing `ANTHROPIC_API_KEY=sk-ant-api03-` followed by 90 random
characters, commit, push, open a PR: the `secrets` job fails and names the file and line, redacted. Delete the file,
amend, force-push: it still fails, because the secret is in the branch's history. The fix in real life is rotating the
key; the fix for the PR is squashing or rebasing it away. Lesson: `--redact` and full-history scanning are not optional.

**A vulnerable dependency.** Pin `requests==2.19.1` in `requirements.txt` on a branch (an old release with known fixed
CVEs). Trivy fails the build and names the CVE and the fixed version. Dependabot would have proposed the fix on its own
the following week.

**An unpinned Action.** Change `actions/checkout@3d3c…` to `actions/checkout@v7` on a branch. Nothing fails yet, which is
the uncomfortable truth: the pipeline cannot know a tag will stay honest. Step 17's nightly job adds a check that every
`uses:` is a 40-character SHA. Revert.

**A broken manifest.** Set `runAsNonRoot: false` in the chart's `podSecurityContext` on a branch: kube-linter fails the
`manifests` job before any image is built.

### 16.5 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `build` fails at push with 403 | package exists from Step 4 under your personal PAT, not linked to the repo | GitHub → Packages → bank-agent → Package settings → Manage Actions access → add the repository with Write |
| `cosign sign` fails with OIDC error | job lacks `id-token: write`, or the run is a PR from a fork | permissions are set in the file; PRs from forks never get tokens and never push |
| Trivy fails on a CVE in the base image | new fix published upstream | rebuild (the base tag floats to the patched image); if no fix exists it is reported, not blocking |
| `test` job cannot reach Postgres | service not healthy yet | the health check waits up to 50 s; check the job's service logs |
| gitleaks flags a runbook example | key-shaped placeholder | add the exact placeholder to `.gitleaks.toml` regexes, never disable the rule |
| Dependabot PR fails CI | the bump broke a test or an eval | that is the gate working; read the failure before merging |

### 16.6 Done when

- A pull request runs all five jobs and the build stops before pushing; `main` publishes a signed image with an SBOM.
- `cosign verify` succeeds from your laptop against the workflow identity, and fails against a wrong identity regexp.
- The secret-leak drill was refused; the vulnerable-dependency drill was refused; a Dependabot PR has appeared.

### Next: Step 17 `[OPS]`

The eval gate: promptfoo with a golden dataset of banking conversations (including the injected transaction memo), a
smoke run on every pull request and a full run nightly, a CI-only budget-capped gateway key, and the nightly drift job:
model-deprecation check, running-digest vulnerability rescan, and the unpinned-Action check.
