#!/usr/bin/env bash
# Step 11: LiteLLM gateway on Kubernetes (new chart deploy/chart/litellm), app chart pointed at the in-cluster gateway,
#          gateway config relocated into the chart (one file for Compose and Kubernetes), runbook for Steps 11-14.
# Run from the repo root:  bash step11-files.sh      (or paste the blocks below into a terminal)
# Delimiter is quoted ('EOF') so ${VAR} and $(...) inside the files are written literally, not expanded.
set -euo pipefail
[ -f agent.py ] || { echo 'run this from the bank-agent repo root'; exit 1; }

# the gateway config moved into the chart; remove the old copy so there is one source of truth
rm -f deploy/litellm/config.yaml && rmdir deploy/litellm 2>/dev/null || true
echo "removed deploy/litellm/config.yaml (moved to deploy/chart/litellm/files/config.yaml)"

mkdir -p "deploy/chart/litellm"
cat << 'EOF' > deploy/chart/litellm/Chart.yaml
apiVersion: v2
name: litellm
description: South AI gateway (LiteLLM proxy) with its Postgres and Redis, for the bank-agent platform track
type: application
version: 0.1.0
# [OPS] the proxy image tag is pinned in values.yaml; this appVersion is informational
appVersion: "main-stable"
EOF
echo "wrote deploy/chart/litellm/Chart.yaml"

mkdir -p "deploy/chart/litellm"
cat << 'EOF' > deploy/chart/litellm/values.yaml
# deploy/chart/litellm/values.yaml
# [OPS] The gateway is Tier-0: every model call of every agent passes through it. Two replicas from day one,
#       shared state in Redis, keys/budgets/spend in Postgres. Release name MUST be "litellm": the app's config
#       points at http://litellm.litellm.svc:4000 and the DATABASE_URL in the Secret points at litellm-postgres.

replicaCount: 2

image:
  repository: ghcr.io/berriai/litellm
  tag: main-stable          # [OPS] stable channel, a moving tag. Pin: set digest after the first pull and commit it.
  digest: ""                # sha256:... wins over tag when set
  pullPolicy: IfNotPresent

# [OPS] created imperatively, never by the chart. Keys expected:
#   ANTHROPIC_API_KEY, LITELLM_MASTER_KEY, LITELLM_SALT_KEY, UI_USERNAME, UI_PASSWORD, POSTGRES_PASSWORD, DATABASE_URL
existingSecret: litellm-secrets

service:
  port: 4000

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "2"
    memory: 1Gi

# [OPS] the proxy runs Prisma migrations at first start: the startup probe gives it two minutes before liveness applies
probes:
  startupFailureThreshold: 60
  startupPeriodSeconds: 2

podDisruptionBudget:
  enabled: true
  minAvailable: 1

postgres:
  enabled: true
  image: postgres:16-alpine
  storage: 1Gi
  storageClassName: ""      # empty = the cluster default (hostpath on Docker Desktop, managed disk on AKS)
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: "1"
      memory: 512Mi

redis:
  enabled: true
  image: redis:7-alpine
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 500m
      memory: 256Mi
EOF
echo "wrote deploy/chart/litellm/values.yaml"

mkdir -p "deploy/chart/litellm"
cat << 'EOF' > deploy/chart/litellm/values-dev.yaml
# deploy/chart/litellm/values-dev.yaml — laptop overrides
replicaCount: 2            # keep 2: the HA and shared-state drills need two gateway pods
resources:
  requests:
    cpu: 100m
    memory: 384Mi
  limits:
    cpu: "2"
    memory: 1Gi
EOF
echo "wrote deploy/chart/litellm/values-dev.yaml"

mkdir -p "deploy/chart/litellm/files"
cat << 'EOF' > deploy/chart/litellm/files/config.yaml
# deploy/litellm/config.yaml
# The south AI gateway. Split of responsibilities:
#   this file (git)  -> models, aliases, fallbacks, retries, timeouts, privacy settings   = configuration
#   the admin UI/DB  -> teams, virtual keys, budgets, rate limits, spend, logs            = data
# Run locally: docker compose up -d        UI: http://localhost:4000/ui

model_list:
  # [OPS] the app calls aliases, never raw model IDs. Changing the model behind an alias is a gateway change, not an app release.
  - model_name: bank-primary
    litellm_params:
      model: anthropic/claude-haiku-5-5
      api_key: os.environ/ANTHROPIC_API_KEY   # [OPS] the only place the provider key exists from Step 10 on
  - model_name: bank-fallback
    litellm_params:
      model: anthropic/claude-opus-5-5
      api_key: os.environ/ANTHROPIC_API_KEY

router_settings:
  # [OPS] after retries on bank-primary fail (429, 5xx, timeout), the request is re-sent to bank-fallback:
  #       "pay more rather than fail" on a customer-facing path. Both go to the same provider; a provider-wide
  #       outage needs a second provider or Claude via a second cloud (Bedrock / Vertex) in this list.
  fallbacks:
    - bank-primary: ["bank-fallback"]
  num_retries: 2            # the retries that used to live in the SDK (agent.py line 21). Step 10 sets the SDK to 0.
  allowed_fails: 3          # failures per minute before a deployment is cooled down...
  cooldown_time: 30         # ...and for how long traffic avoids it
  enable_pre_call_checks: true                 # reject requests that cannot fit the model's context window before paying for them
  optional_pre_call_checks: ["prompt_caching"] # keep requests that use Anthropic prompt caching on the same deployment
  # [OPS] shared state for rate limits, budgets and cooldowns across gateway replicas (Step 11). Harmless with one replica.
  redis_host: os.environ/REDIS_HOST
  redis_port: os.environ/REDIS_PORT

litellm_settings:
  drop_params: true         # silently drop request params a provider does not support instead of failing the call
  request_timeout: 120      # [OPS] per model call. Opus on a long answer can take a minute; the edge (APISIX) allows 180
  # [OPS] response caching is OFF on purpose: this traffic is personalised. A cached "your balance is ..." served to
  #       another customer who typed the same words is a data breach. Anthropic prompt caching (cache_control inside a
  #       request) is a different mechanism and is unaffected by this setting.
  cache: false
  # [OPS] dev: logging callbacks (Langfuse, Step 15) may see message content. Production: true, so only metadata leaves.
  turn_off_message_logging: false
  json_logs: true

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY    # [OPS] admin credential for the gateway API and UI; the proxy refuses weak values
  database_url: os.environ/DATABASE_URL        # [OPS] Tier-0 store: keys, teams, budgets, spend. Back it up (Step 11).
  store_model_in_db: false                     # models and routing come from this file, not from the UI
  store_prompts_in_spend_logs: false           # spend logs keep tokens, cost, latency, key; never prompt or response text (PII)
  maximum_spend_logs_retention_period: 30d     # [OPS] data retention is a setting, not an afterthought
  # [OPS] the real throttle behind autoscaling: concurrency ceilings at the gateway, per deployment and overall.
  #       Past the provider quota, more agent pods only produce more 429s; this is where that is bounded.
  max_parallel_requests: 20
  global_max_parallel_requests: 40
EOF
echo "wrote deploy/chart/litellm/files/config.yaml"

mkdir -p "deploy/chart/litellm/templates"
cat << 'EOF' > deploy/chart/litellm/templates/_helpers.tpl
{{- define "litellm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "litellm.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "litellm.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "litellm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "litellm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "litellm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "litellm.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}
EOF
echo "wrote deploy/chart/litellm/templates/_helpers.tpl"

mkdir -p "deploy/chart/litellm/templates"
cat << 'EOF' > deploy/chart/litellm/templates/configmap.yaml
# [OPS] the gateway configuration, verbatim from files/config.yaml (the same file Compose mounts).
#       A change to it changes the checksum annotation on the Deployment, which rolls the gateway pods.
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "litellm.fullname" . }}-config
  labels:
    {{- include "litellm.labels" . | nindent 4 }}
data:
  config.yaml: |-
{{ .Files.Get "files/config.yaml" | indent 4 }}
EOF
echo "wrote deploy/chart/litellm/templates/configmap.yaml"

mkdir -p "deploy/chart/litellm/templates"
cat << 'EOF' > deploy/chart/litellm/templates/deployment.yaml
# The gateway itself. Stateless: all state is in Postgres (keys, budgets, spend) and Redis (rate limits, cooldowns),
# which is what makes two replicas behave as one gateway.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "litellm.fullname" . }}
  labels:
    {{- include "litellm.labels" . | nindent 4 }}
    app.kubernetes.io/component: proxy
  annotations:
    # [OPS] documented exceptions, not silent ones: the upstream image picks its own user and writes at startup
    #       (Prisma). Rebuilding it non-root and read-only is tracked for Module 6 (Kyverno will enforce it then).
    ignore-check.kube-linter.io/run-as-non-root: "upstream litellm image; hardened rebuild planned in Module 6"
    ignore-check.kube-linter.io/no-read-only-root-fs: "upstream litellm image writes at startup; hardened rebuild planned in Module 6"
spec:
  replicas: {{ .Values.replicaCount }}
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      {{- include "litellm.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: proxy
  template:
    metadata:
      labels:
        {{- include "litellm.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: proxy
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      serviceAccountName: {{ include "litellm.fullname" . }}
      automountServiceAccountToken: false
      # [OPS] in-flight model calls finish before the pod goes; the gateway's own request_timeout is 120 s
      terminationGracePeriodSeconds: 150
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    {{- include "litellm.selectorLabels" . | nindent 20 }}
                    app.kubernetes.io/component: proxy
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: litellm
          image: {{ include "litellm.image" . }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          args: ["--config", "/app/config.yaml", "--port", "4000"]
          ports:
            - name: http
              containerPort: 4000
          # [OPS] every secret the gateway needs, and only the gateway: provider key, master key, salt, DB URL, UI login
          envFrom:
            - secretRef:
                name: {{ .Values.existingSecret }}
          env:
            - name: REDIS_HOST
              value: {{ include "litellm.fullname" . }}-redis
            - name: REDIS_PORT
              value: "6379"
          # [OPS] the upstream image chooses its own user; we drop what we can without rebuilding it.
          #       Rebuilding the gateway image non-root and read-only is a Module 6 item.
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          # [OPS] first start runs database migrations: startup probe allows startupFailureThreshold x period seconds
          startupProbe:
            httpGet:
              path: /health/liveliness
              port: http
            periodSeconds: {{ .Values.probes.startupPeriodSeconds }}
            failureThreshold: {{ .Values.probes.startupFailureThreshold }}
          # [OPS] liveliness = process answers. Never the provider.
          livenessProbe:
            httpGet:
              path: /health/liveliness
              port: http
            periodSeconds: 10
            failureThreshold: 3
          # [OPS] readiness = can serve: includes the database connection. A pod that lost Postgres leaves the Service.
          readinessProbe:
            httpGet:
              path: /health/readiness
              port: http
            periodSeconds: 10
            failureThreshold: 3
          volumeMounts:
            - name: config
              mountPath: /app/config.yaml
              subPath: config.yaml
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: {{ include "litellm.fullname" . }}-config
EOF
echo "wrote deploy/chart/litellm/templates/deployment.yaml"

mkdir -p "deploy/chart/litellm/templates"
cat << 'EOF' > deploy/chart/litellm/templates/pdb.yaml
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "litellm.fullname" . }}
  labels:
    {{- include "litellm.labels" . | nindent 4 }}
spec:
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  unhealthyPodEvictionPolicy: AlwaysAllow
  # [OPS] proxy pods only. Without the component label this PDB would also cover the single Postgres pod and block
  #       every node drain forever: the linter caught exactly that.
  selector:
    matchLabels:
      {{- include "litellm.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: proxy
{{- end }}
EOF
echo "wrote deploy/chart/litellm/templates/pdb.yaml"

mkdir -p "deploy/chart/litellm/templates"
cat << 'EOF' > deploy/chart/litellm/templates/postgres.yaml
{{- if .Values.postgres.enabled }}
# [OPS] Tier-0 state. A StatefulSet gives the pod a stable name and a PersistentVolumeClaim that survives restarts;
#       the data outlives the pod. Production: a managed service (Azure Database for PostgreSQL) or an operator
#       (CloudNativePG) with automated backups. This single-replica Postgres is the lab stand-in.
apiVersion: v1
kind: Service
metadata:
  name: {{ include "litellm.fullname" . }}-postgres
  labels:
    {{- include "litellm.labels" . | nindent 4 }}
    app.kubernetes.io/component: postgres
spec:
  clusterIP: None
  selector:
    {{- include "litellm.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: postgres
  ports:
    - name: postgres
      port: 5432
      targetPort: postgres
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "litellm.fullname" . }}-postgres
  labels:
    {{- include "litellm.labels" . | nindent 4 }}
    app.kubernetes.io/component: postgres
spec:
  serviceName: {{ include "litellm.fullname" . }}-postgres
  replicas: 1
  selector:
    matchLabels:
      {{- include "litellm.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: postgres
  template:
    metadata:
      labels:
        {{- include "litellm.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: postgres
    spec:
      automountServiceAccountToken: false
      # [OPS] the alpine postgres image runs as uid 70; fsGroup makes the volume writable for it
      securityContext:
        runAsNonRoot: true
        runAsUser: 70
        runAsGroup: 70
        fsGroup: 70
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: postgres
          image: {{ .Values.postgres.image }}
          ports:
            - name: postgres
              containerPort: 5432
          env:
            - name: POSTGRES_USER
              value: litellm
            - name: POSTGRES_DB
              value: litellm
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.existingSecret }}
                  key: POSTGRES_PASSWORD
            # a subdirectory, so the volume's lost+found does not confuse initdb
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          resources:
            {{- toYaml .Values.postgres.resources | nindent 12 }}
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "litellm", "-d", "litellm"]
            periodSeconds: 5
          livenessProbe:
            exec:
              command: ["pg_isready", "-U", "litellm", "-d", "litellm"]
            periodSeconds: 20
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
            # read-only root filesystem: the two places postgres writes outside the data directory
            - name: run
              mountPath: /var/run/postgresql
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: run
          emptyDir: {}
        - name: tmp
          emptyDir: {}
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        {{- with .Values.postgres.storageClassName }}
        storageClassName: {{ . }}
        {{- end }}
        resources:
          requests:
            storage: {{ .Values.postgres.storage }}
{{- end }}
EOF
echo "wrote deploy/chart/litellm/templates/postgres.yaml"

mkdir -p "deploy/chart/litellm/templates"
cat << 'EOF' > deploy/chart/litellm/templates/redis.yaml
{{- if .Values.redis.enabled }}
# [OPS] shared gateway state: rate-limit counters, cooldowns, budgets across replicas. Rebuildable, so no persistence.
apiVersion: v1
kind: Service
metadata:
  name: {{ include "litellm.fullname" . }}-redis
  labels:
    {{- include "litellm.labels" . | nindent 4 }}
    app.kubernetes.io/component: redis
spec:
  selector:
    {{- include "litellm.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: redis
  ports:
    - name: redis
      port: 6379
      targetPort: redis
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "litellm.fullname" . }}-redis
  labels:
    {{- include "litellm.labels" . | nindent 4 }}
    app.kubernetes.io/component: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      {{- include "litellm.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: redis
  template:
    metadata:
      labels:
        {{- include "litellm.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: redis
    spec:
      automountServiceAccountToken: false
      # the alpine redis image runs as uid 999
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: redis
          image: {{ .Values.redis.image }}
          args: ["redis-server", "--save", "", "--appendonly", "no"]
          ports:
            - name: redis
              containerPort: 6379
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          resources:
            {{- toYaml .Values.redis.resources | nindent 12 }}
          readinessProbe:
            exec:
              command: ["redis-cli", "ping"]
            periodSeconds: 5
          livenessProbe:
            exec:
              command: ["redis-cli", "ping"]
            periodSeconds: 20
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          emptyDir: {}
{{- end }}
EOF
echo "wrote deploy/chart/litellm/templates/redis.yaml"

mkdir -p "deploy/chart/litellm/templates"
cat << 'EOF' > deploy/chart/litellm/templates/service.yaml
# [OPS] ClusterIP only. The agent reaches it as http://litellm.litellm.svc:4000; nothing outside the cluster can.
apiVersion: v1
kind: Service
metadata:
  name: {{ include "litellm.fullname" . }}
  labels:
    {{- include "litellm.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    {{- include "litellm.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: proxy
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
EOF
echo "wrote deploy/chart/litellm/templates/service.yaml"

mkdir -p "deploy/chart/litellm/templates"
cat << 'EOF' > deploy/chart/litellm/templates/serviceaccount.yaml
# [OPS] dedicated identity, no Kubernetes API permissions, no token mounted
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "litellm.fullname" . }}
  labels:
    {{- include "litellm.labels" . | nindent 4 }}
automountServiceAccountToken: false
EOF
echo "wrote deploy/chart/litellm/templates/serviceaccount.yaml"

mkdir -p "deploy/chart/bank-agent"
cat << 'EOF' > deploy/chart/bank-agent/Chart.yaml
apiVersion: v2
name: bank-agent
description: Claude-powered retail-banking assistant (FDE / GenAIOps training track)
type: application
# [OPS] chart version: bump whenever a template changes
version: 0.3.0
# [OPS] app version: becomes the default image tag
appVersion: "0.4.0"
EOF
echo "wrote deploy/chart/bank-agent/Chart.yaml"

mkdir -p "deploy/chart/bank-agent"
cat << 'EOF' > deploy/chart/bank-agent/values.yaml
# deploy/chart/bank-agent/values.yaml
# [OPS] Defaults are production-leaning. Environment files (values-dev.yaml) override only what differs.
#       Everything that was hard-coded in deploy/k8s/*.yaml is a knob here.

replicaCount: 2

image:
  repository: ghcr.io/CHANGE-ME/bank-agent
  tag: ""             # empty = Chart.appVersion
  digest: ""          # [OPS] when set (sha256:...) it wins over tag. CI stamps this in Module 5.
  pullPolicy: IfNotPresent

# [OPS] created imperatively (Step 5), never by the chart
imagePullSecrets:
  - name: ghcr-pull

# [OPS] non-secret config -> ConfigMap. Any change here rolls the pods (checksum annotation on the Deployment).
#       Step 11: the app talks to the in-cluster gateway and calls an alias; retries belong to the gateway.
config:
  ANTHROPIC_BASE_URL: http://litellm.litellm.svc:4000
  MODEL_ID: bank-primary
  SDK_MAX_RETRIES: "0"
  LOG_LEVEL: INFO

# [OPS] secret config is referenced, never created here. External Secrets Operator fills it in Module 6.
#       Step 11: ANTHROPIC_API_KEY in this Secret is a LiteLLM virtual key, not the provider key.
existingSecret: bank-agent-secrets

# [OPS] dedicated identity with zero permissions and no API token: least privilege by default
serviceAccount:
  create: true
  name: ""
  automountToken: false

service:
  type: ClusterIP
  port: 80

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: "1"
    memory: 256Mi

probes:
  startup:
    path: /health
    periodSeconds: 2
    failureThreshold: 30
  liveness:
    path: /health
    periodSeconds: 10
    failureThreshold: 3
  readiness:
    path: /ready
    periodSeconds: 5
    failureThreshold: 2

terminationGracePeriodSeconds: 90
preStopSleepSeconds: 5

strategy:
  maxUnavailable: 0
  maxSurge: 1

# [OPS] soft = prefer spreading across nodes, never block scheduling (right for a laptop and most clusters)
#       hard = refuse to co-locate (multi-node production only); none = off
antiAffinity: soft

podDisruptionBudget:
  enabled: true
  minAvailable: 1

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]

# [OPS] Prometheus scrapes /metrics through a ServiceMonitor. Needs the Prometheus Operator CRDs (kube-prometheus-stack).
metrics:
  serviceMonitor:
    enabled: false
    interval: 15s
    labels:
      release: monitoring

# [OPS] KEDA scales on in-flight /chat requests per pod, the honest signal for an I/O-bound service.
#       When enabled, the Deployment's replicas field is omitted so Helm never fights the autoscaler.
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 6
  inFlightPerPod: 4
  pollingInterval: 10
  cooldownPeriod: 60
  prometheusAddress: http://monitoring-kube-prometheus-prometheus.monitoring.svc:9090

podAnnotations: {}
nodeSelector: {}
tolerations: []
EOF
echo "wrote deploy/chart/bank-agent/values.yaml"

mkdir -p "deploy/k8s"
cat << 'EOF' > deploy/k8s/10-configmap.yaml
# deploy/k8s/10-configmap.yaml
# [OPS] Non-secret configuration: the same keys as .env minus the secret.
#       Changing MODEL_ID here is a config rollout, not an image rebuild.
#       Note: pods do not restart on ConfigMap edits; `kubectl rollout restart` (Helm automates this in Step 6).
apiVersion: v1
kind: ConfigMap
metadata:
  name: bank-agent-config
  namespace: bank-agent
  labels:
    app.kubernetes.io/name: bank-agent
data:
  # Step 11 (reference only; the Helm chart is what gets deployed): the app calls the in-cluster gateway by alias
  ANTHROPIC_BASE_URL: "http://litellm.litellm.svc:4000"
  MODEL_ID: "bank-primary"
  SDK_MAX_RETRIES: "0"
  LOG_LEVEL: "INFO"
EOF
echo "wrote deploy/k8s/10-configmap.yaml"

cat << 'EOF' > docker-compose.yml
# bank-agent / Step 9 — the local stack: agent + south AI gateway (LiteLLM) + its Postgres + Redis.
# [OPS] Each service receives exactly the variables it needs, interpolated from .env by Compose.
#       No service gets the whole .env: the agent never sees the gateway's master key, and after Step 10
#       the agent will not see the provider key either. Same principle as one Kubernetes Secret per workload.
services:
  agent:
    build: .
    # [OPS] tag = app version. Never :latest. In Module 5 CI stamps the git SHA here.
    image: bank-agent:0.4.0
    environment:
      # [OPS] Step 10: the SDK reads these two natively. The app now talks to the gateway and holds a revocable,
      #       budgeted virtual key. The provider key no longer exists anywhere in the app's world.
      ANTHROPIC_BASE_URL: http://litellm:4000
      ANTHROPIC_API_KEY: ${LITELLM_VIRTUAL_KEY}
      MODEL_ID: bank-primary          # an alias; the gateway decides Haiku or Opus
      SDK_MAX_RETRIES: "0"            # the gateway owns retries now; two retry layers multiply
      LOG_LEVEL: INFO
    depends_on:
      litellm:
        condition: service_healthy
    ports:
      - "8000:8000"
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits:
          cpus: "0.50"
          memory: 256M
    restart: unless-stopped

  postgres:
    # [OPS] Tier-0 for the gateway: every virtual key, team, budget and spend record lives here. Losing it = total
    #       outage of the model path. Pinned major version; backups and HA come with Step 11.
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: litellm
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: litellm
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U litellm -d litellm"]
      interval: 5s
      timeout: 3s
      retries: 10
    deploy:
      resources:
        limits:
          memory: 512M
    restart: unless-stopped

  redis:
    # [OPS] shared state for the gateway (rate limits, cooldowns, budgets across replicas) and, from Step 12,
    #       the agent's conversation memory. Persistence off for now: everything in it is rebuildable.
    image: redis:7-alpine
    command: ["redis-server", "--save", "", "--appendonly", "no"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10
    deploy:
      resources:
        limits:
          memory: 256M
    restart: unless-stopped

  litellm:
    # [OPS] "main-stable" is the stable release channel, a moving tag. Pin it after the first pull:
    #       docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/berriai/litellm:main-stable   -> image: ...@sha256:...
    image: ghcr.io/berriai/litellm:main-stable
    command: ["--config", "/app/config.yaml", "--port", "4000"]
    environment:
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}     # [OPS] provider key: held only by the gateway
      LITELLM_MASTER_KEY: ${LITELLM_MASTER_KEY}   # [OPS] admin credential; UI login when UI_* are unset
      LITELLM_SALT_KEY: ${LITELLM_SALT_KEY}       # [OPS] encrypts credentials stored in the DB; set once, never rotate
      UI_USERNAME: ${UI_USERNAME:-admin}
      UI_PASSWORD: ${UI_PASSWORD}
      DATABASE_URL: postgresql://litellm:${POSTGRES_PASSWORD}@postgres:5432/litellm
      REDIS_HOST: redis
      REDIS_PORT: "6379"
    volumes:
      # [OPS] one file, two consumers: Compose mounts it here; the Kubernetes ConfigMap in deploy/chart/litellm renders the same file
      - ./deploy/chart/litellm/files/config.yaml:/app/config.yaml:ro
    ports:
      - "4000:4000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      # [OPS] liveliness only: "is the gateway process up". Never a probe that calls the provider.
      test: ["CMD", "python3", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:4000/health/liveliness', timeout=3)"]
      interval: 15s
      timeout: 5s
      start_period: 60s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 1G
    restart: unless-stopped

volumes:
  pgdata:
EOF
echo "wrote docker-compose.yml"

mkdir -p "docs"
cat << 'EOF' > docs/runbook-steps-11-14.md
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
EOF
echo "wrote docs/runbook-steps-11-14.md"

echo "step11: 17 files written"