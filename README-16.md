## Step 16 — CI: lint, test, scan, sign, push `[OPS]`

### What changes and why

Until now every check ran by hand: ruff and hadolint on my side, Trivy and Cosign through `release.sh` on yours. This step makes the checks a gate that no change can skip, and it does so with the March 2026 LiteLLM compromise as the template of what a pipeline must not do: that attack started with a poisoned scanner Action running inside a CI job with access to publishing tokens.

- **`.github/workflows/ci.yaml`**, five jobs. `lint` (ruff, hadolint), `test` (pytest with a fake model and a real
  pgvector service container), `secrets` (gitleaks over the full history), `manifests` (helm lint, kube-linter), and
  `build` which needs the other four and does build → Trivy gate → push → keyless sign → SBOM → attestation → verify.   Pull requests run everything except the push; `main` publishes.

- **Five rules the file follows, each visible in it.** Every Action pinned to a full commit SHA (the `# vN` comment is
  for humans and Dependabot). Scanners downloaded as release binaries and verified against the publisher's checksums   (hadolint has no checksum file, so its hash is pinned directly). `GITHUB_TOKEN` is read-only by default and widened per  job: only `build` may write packages and mint an OIDC token. Signing is keyless: the workflow's identity is the   signature, verifiable by anyone with no key material. One run per branch; superseded PR runs are cancelled.
- **`tests/`**: the offline checks from Steps 1–15 become a permanent suite (29 tests). `conftest.py` scripts the model  and replaces Redis; nothing touches the network. Two tests need Postgres with pgvector and skip themselves when there is none; CI provides one as a service container, so they run on every pull request.

- **`pyproject.toml`**: ruff and pytest settings; the same commands work locally. `ruff format` reformatted the six  Python files (whitespace only, no logic). From now on, formatting is enforced, not discussed.
- **`.gitleaks.toml`**: default rules plus an allow-list for documented placeholders (`.env.example`, `REPLACE_ME`,  the runbooks' key shapes). **`.kube-linter.yaml`**: the lab's single-replica stores are exempt from the anti-affinity check.
- **`.github/dependabot.yml`**: pinned versions rot unless something proposes updates. Dependabot opens weekly pull  requests for Actions (it understands SHA pins), pip pins and the Dockerfile base image, and every proposal runs this  pipeline, plus the eval gate from Step 17, before a human merges.

### 16.1 Get the files, run the checks locally first

```bash
bash ~/Downloads/step16-files.sh
pip install ruff==0.17.1 pytest==9.1.1
pip install -r requirements.txt 
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

GitHub → Actions → `ci`: four jobs in parallel (lint, test, secrets, manifests), then `build`. On `main` the build pushes `ghcr.io/<owner>/bank-agent:sha-<7 chars>` and `:<full sha>`, signs the digest, attaches the SBOM, verifies both, and writes the digest into the run's summary.

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

**A vulnerable dependency.** Pin `requests==2.19.1` in `requirements.txt` on a branch (an old release with known fixed CVEs). Trivy fails the build and names the CVE and the fixed version. Dependabot would have proposed the fix on its own the following week.

**An unpinned Action.** Change `actions/checkout@3d3c…` to `actions/checkout@v7` on a branch. Nothing fails yet, which is the uncomfortable truth: the pipeline cannot know a tag will stay honest. Step 17's nightly job adds a check that every `uses:` is a 40-character SHA. Revert.

**A broken manifest.** Set `runAsNonRoot: false` in the chart's `podSecurityContext` on a branch: kube-linter fails the`manifests` job before any image is built.

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
