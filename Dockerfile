# syntax=docker/dockerfile:1
# bank-agent / Step 3 — hardened multi-stage image.
#
# Stage 1 (builder) resolves and installs the dependency tree.
# Stage 2 (runtime) ships only the interpreter, the installed packages and two .py files.
# pip, build caches and the pip toolchain never reach production: build server vs. runtime node.
#
# Dockerfile comments must be on their own line (no trailing comments), hence the layout below.

# ---------------------------------------------------------------- Stage 1: builder
# [OPS] slim = Debian minus docs, locales and most tooling. Fewer packages, fewer CVEs for Trivy to find.
FROM python:3.12-slim AS builder

# [OPS] no pip cache or version nag inside the image
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# Build happens in its own directory; nothing from here is copied except /opt/venv
WORKDIR /build

# One isolated directory we can copy to the runtime stage as a unit
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy only the lockfile first: this layer is cached until requirements.txt changes
COPY requirements.txt .
RUN pip install -r requirements.txt

# ---------------------------------------------------------------- Stage 2: runtime
# [OPS] production hardening step for later: pin by digest, e.g. python:3.12-slim@sha256:<digest>
#       (docker buildx imagetools inspect python:3.12-slim). Renovate/Dependabot keep the digest fresh.
FROM python:3.12-slim

# [OPS] OCI labels: GHCR links the image to its repo; tooling reads these
LABEL org.opencontainers.image.title="bank-agent" \
      org.opencontainers.image.description="Claude-powered retail-banking assistant" \
      org.opencontainers.image.source="https://github.com/sidd-harth/bank-agent"

# [OPS] no .pyc writes (read-only filesystem later), unbuffered stdout (logs flush immediately), venv on PATH
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# [OPS] non-root service account. UID above 10000 cannot collide with any host user.
RUN groupadd --gid 10001 appuser \
 && useradd --uid 10001 --gid appuser --system --no-create-home appuser

WORKDIR /app

# Dependencies only; pip and its toolchain stay behind in stage 1
COPY --from=builder /opt/venv /opt/venv

# Explicit file list, never "COPY . ." : nothing unlisted (.env, .venv, .git) can ever leak into the image
COPY --chown=appuser:appuser agent.py app.py memory.py ./
# Step 12: the prompt ships with the code it was tested with; a different file can be mounted over it per environment
COPY --chown=appuser:appuser prompts/ ./prompts/

# [OPS] everything from here on runs unprivileged. Numeric form on purpose: Kubernetes' runAsNonRoot
#       check can only verify a numeric UID; "USER appuser" would be rejected by that policy.
USER 10001:10001

EXPOSE 8000

# [OPS] Docker and Compose use this; Kubernetes ignores it and uses the probes in the manifest instead.
#       slim has no curl, so Python's stdlib does the check.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"]

# Exec form: uvicorn is PID 1, receives SIGTERM directly and drains in-flight requests on shutdown.
# One process per container; concurrency comes from replicas, not --workers.
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
