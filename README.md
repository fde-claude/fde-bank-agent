# bank-agent

Claude-powered retail-banking customer-service agent, built as a thin vertical slice
for the FDE / GenAIOps training track. Native Anthropic SDK, no framework.

## Run locally
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env            # add your ANTHROPIC_API_KEY
python agent.py "What is the balance on ACC-1001?"   # CLI
uvicorn app:app --reload --port 8000                 # HTTP: /chat /health /ready /docs
```

## Run as a container
```bash
docker compose up --build        # hardened image: slim, non-root, read-only FS
```

## Release (build, scan, push, sign, SBOM)
```bash
OWNER=<github-user> VERSION=0.2.0 ./scripts/release.sh
```

## Layout
- `agent.py`   the agent loop and tools (DEV)
- `app.py`     FastAPI wrapper with liveness/readiness probes (DEV)
- `Dockerfile`, `docker-compose.yml`, `scripts/`   packaging and release (OPS)
- `cosign.pub` public key used to verify image signatures (OPS)
- `deploy/`    Kubernetes manifests and Helm chart (OPS, from Module 3)
