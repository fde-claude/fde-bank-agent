# Step 16: Hardened CI Pipeline & Supply Chain Security
> **Status:** Delivered. Module 5 begins. Seventeen files packaged via `step16-files.sh` (heredoc) and `step16-files.zip`.  
> **Documentation:** Step 16 section in `docs/runbook-steps-15-19.md`.

---

### Overview & Verification
- **Milestone:** Replaces local, manual release scripts with a hardened, automated **GitHub Actions CI/CD pipeline** enforcing strict supply chain security, automated testing, container vulnerability gating, and **keyless Sigstore/Cosign signing** via GitHub OIDC.
- **Verification Details:**
  - **Pipeline Validation:** Workflow syntax verified using `actionlint`.
  - **Local Test Suite:** 29 automated tests pass locally (27 run without external dependencies; 2 database tests execute against a local `pgvector` container).
  - **Code Quality & Secrets:** Passed `ruff`, `ruff format --check`, and `gitleaks` scans across the entire git history with zero findings.
  - **Manifest Checks:** Helm linting and `kube-linter` pass cleanly against the `.kube-linter.yaml` policy.
  - **Binary Integrity Verification:** Every scanner binary download and checksum verification step was tested against publisher release digests (Trivy, Gitleaks, Syft, and Hadolint).

---

## Supply Chain Threat Model: The "March Incident" Context

The March LiteLLM supply chain incident illustrated a common CI attack vector: **a compromised build-time scanner action leveraged over-privileged CI tokens to steal release credentials and hijack container registries.**

To mitigate this attack surface, every step of this pipeline adheres to five strict guardrails:

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│        ATTACK VECTOR            │       │      OUR DEFENSIVE CONTROL      │
├─────────────────────────────────┤       ├─────────────────────────────────┤
│ Mutated Action tag (v1 -> evil) │  ==>  │ Immutable commit SHA pinning    │
│ Tampered tool binary download   │  ==>  │ Cryptographic SHA-256 checksums │
│ Stolen pipeline credentials     │  ==>  │ Read-only GITHUB_TOKEN default  │
│ Exfiltrated long-lived keys     │  ==>  │ Keyless OIDC signing (Sigstore) │
│ Resource exhaustion / race bugs │  ==>  │ Concurrency cancellation gates  │
└─────────────────────────────────┘       └─────────────────────────────────┘
```

---

## The Five Pipeline Jobs (`.github/workflows/ci.yaml`)

```
   ┌─────────┐   ┌─────────┐   ┌───────────┐   ┌─────────────┐
   │  lint   │   │  test   │   │  secrets  │   │  manifests  │
   └────┬────┘   └────┬────┘   └─────┬─────┘   └──────┬──────┘
        │             │              │                │
        └─────────────┴───────┬──────┴────────────────┘
                              ▼
                     ┌─────────────────┐
                     │      build      │ (Waits for all 4; main branch only)
                     └─────────────────┘
```

1. **`lint`:** Executes `ruff check`, `ruff format --check`, and `hadolint` (Dockerfiles).
2. **`test`:** Runs the full 29-test offline pytest suite against a live `pgvector/pgvector:pg16` service container.
3. **`secrets`:** Runs `gitleaks detect --redact` across full git commit history to detect leaked credentials.
4. **`manifests`:** Runs `helm lint` and `kube-linter` across all Helm chart templates.
5. **`build` (Gate & Publish):**
   - **Branch Scoping:** Pull requests execute build and vulnerability scans without pushing; merges to `main` publish.
   - **Trivy Vulnerability Gate:** Fails the build on unfixed `HIGH` or `CRITICAL` vulnerabilities (`--exit-code 1`).
   - **Push to GHCR:** Pushes image by immutable digest.
   - **Keyless Signing (Cosign + GitHub OIDC):** Signs the image digest using GitHub’s short-lived OIDC token. No long-lived private keys exist in repository secrets.
   - **SBOM & Attestation:** Syft generates an **SPDX 2.3 JSON** Software Bill of Materials, which is attached to the image as a signed Cosign attestation.
   - **Job Summary:** Outputs the verified image digest directly into the GitHub Actions run summary.

---

## Supply Chain Hardening Rules

1. **Immutable Action Pinning:** Every third-party GitHub Action is pinned to a 40-character commit SHA, with a version comment for human readability and Dependabot compatibility:
   ```yaml
   uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
   ```
2. **Cryptographic Tool Integrity:** Scanners are retrieved as direct release binaries verified against the publisher’s published SHA-256 checksums before execution:
   ```bash
   # Example: Download and checksum verification
   curl -sSfL -o trivy.tar.gz https://github.com/aquasecurity/trivy/releases/download/...
   echo "${TRIVY_SHA256}  trivy.tar.gz" | sha256sum -c -
   tar -xzf trivy.tar.gz && sudo mv trivy /usr/local/bin/
   ```
3. **Least Privilege Tokens:** The default workflow-wide permission is restricted to `read-all`. Permissions are elevated explicitly only in the `build` job:
   ```yaml
   permissions:
     packages: write  # To push image to GHCR
     id-token: write  # To obtain GitHub OIDC token for Cosign keyless signing
   ```
4. **Keyless Sigstore Signing:** Uses the workflow's cryptographic OIDC identity (`https://github.com/<owner>/<repo>/.github/workflows/ci.yaml@refs/heads/main`) as the signing certificate.
5. **Concurrency Control:**
   ```yaml
   concurrency:
     group: ${{ github.workflow }}-${{ github.ref }}
     cancel-in-progress: true
   ```
   Cancels outdated in-flight runs when new commits are pushed to a pull request.

---

## Test Suite & Tooling Configuration

### 1. Offline Test Suite (`tests/` — 29 Tests)
Consolidates checks from Steps 1–15 into an automated test suite:
- **`conftest.py`:** Mocks Anthropic API responses and substitutes Redis with an in-memory dictionary; test runs require zero external network calls.
- **Database Integration:** 27 unit tests run completely standalone. 2 RAG vector search tests automatically skip themselves when PostgreSQL is absent, and execute in CI against the `pgvector` service container.

### 2. Standardized Tooling Configs
- **`pyproject.toml`:** Centralizes `ruff` linting/formatting rules and `pytest` paths so developer laptops and CI run identical commands.
- **`.gitleaks.toml`:** Custom allowlist protecting legitimate educational mock tokens (e.g., `sk-mock-...`) while blocking actual secrets.
- **`.kube-linter.yaml`:** Configures exceptions (exempting single-replica development databases from production pod anti-affinity rules).
- **`.github/dependabot.yml`:** Weekly updates for GitHub Actions, Python dependencies (`requirements.txt`), and container base images (`python:3.12-slim`).

---

## Execution Runbook & Verification Steps

### 1. Local Pre-Flight Check (Run on Laptop)
Run the identical checks locally before pushing upstream:

```bash
cd bank-agent
bash scripts/step16-files.sh   # Or unpack step16-files.zip

# 1. Format and lint Python code
ruff format --check .
ruff check .

# 2. Start a local pgvector container for tests
docker run -d --name test-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=knowledge \
  -p 5432:5432 pgvector/pgvector:pg16

# 3. Run all 29 tests
KNOWLEDGE_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/knowledge" pytest -v
docker rm -f test-pg

# 4. Check for secret leaks
gitleaks detect --redact

# 5. Lint Helm chart manifests
helm lint deploy/chart/bank-agent
kube-linter lint deploy/chart/bank-agent --config .kube-linter.yaml
```

---

### 2. Push to GitHub & Monitor CI
```bash
git checkout -b feature/step-16-ci
git add .
git commit -m "feat(ci): add hardened GitHub Actions pipeline with keyless signing"
git push -u origin feature/step-16-ci
```
- Open a Pull Request on GitHub.
- Observe jobs: `lint`, `test`, `secrets`, and `manifests` execute concurrently.
- Verify `build` does **not** push container artifacts on PR branches.
- Merge the Pull Request to `main` to trigger image build, vulnerability scanning, GHCR publishing, and keyless Cosign signing.

---

### Troubleshooting: GHCR 403 Forbidden on Initial Push
If the `build` job fails with `403 Forbidden` while pushing to GHCR:
1. Navigate to **GitHub Profile → Packages → `bank-agent`**.
2. Click **Package Settings** → Scroll down to **Manage Actions access**.
3. Click **Add Repository** → Select `bank-agent` and grant **Write** permissions.
4. Re-run the failed `build` job.

---

### 3. Verify Keyless Image Signature from Laptop
Once published, verify the container image signature locally **without needing any private key files**:

```bash
# Verify the keyless signature against the GitHub OIDC certificate identity
cosign verify \
  --certificate-identity-regexp="https://github.com/${OWNER}/bank-agent/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/${OWNER}/bank-agent:latest

# Verify the attached SPDX SBOM attestation
cosign verify-attestation \
  --type spdxjson \
  --certificate-identity-regexp="https://github.com/${OWNER}/bank-agent/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/${OWNER}/bank-agent:latest
```

---

## Supply Chain Refusal Drills

Validate that the pipeline actively blocks supply chain defects:

- **Drill 1: Leaked Secret Detection**  
  Commit a dummy high-entropy API key (`ghp_...`) into a branch. `gitleaks` flags the commit, failing the `secrets` job and blocking the PR.
- **Drill 2: Vulnerable Dependency Gate**  
  Add a known vulnerable library version to `requirements.txt`. The `build` job halts at the `Trivy` gate with `--exit-code 1`, preventing image publication.
- **Drill 3: Non-Compliant Kubernetes Manifest**  
  Add a pod running as `root` without CPU limits in a template. `kube-linter` fails the `manifests` job and prints remediation instructions.
- **Drill 4: Action Tampering (Preview of Step 17)**  
  Unpinned actions (e.g., `uses: actions/checkout@v4`) are permitted temporarily here, but will be audited and flagged by Step 17’s nightly drift job.

---

## Next Up: Step 17 [OPS] — The Eval Gate & Nightly Drift Detection
- **AI Evaluation Framework:** Deploy **promptfoo** with a golden dataset of banking conversations (including prompt-injection security tests).
- **Graduated Evaluation Strategy:** Run fast smoke evaluations on Pull Requests and the full golden dataset on nightly schedules.
- **CI AI Gateway Key:** Provision a restricted, budget-capped LiteLLM virtual key dedicated exclusively to CI evaluation jobs.
- **Nightly Drift Detection:** Build a scheduled workflow monitoring model deprecations, re-scanning container digests for newly disclosed CVEs, and flagging unpinned GitHub Actions.