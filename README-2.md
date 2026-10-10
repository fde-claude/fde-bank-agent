# Step 4: Supply Chain and Repository Setup
> **Status:** Delivered. This closes **Module 2**.

---

### Overview & Verification
- **Status:** APISIX locked in. Step 3 clean, good.
- **Files touched:**
  - `scripts/release.sh` *(new)*
  - `.gitignore` *(two lines added)*
  - `README.md` *(new)*
  - *(Nothing in the app changes)*
- **Verification details:**
  - `release.sh` passes `bash -n`.
  - Every `cosign` and `syft` flag checked against tool versions (`cosign v3.1.3`, `syft 1.54`).
  - `syft` run against the project folder produced an **SPDX 2.3 SBOM** listing the four pinned packages.
  - *Registry pushes and signing require your GitHub account, so those runs are yours.*

---

## Code / Developer Part

- **Application code:** No changes to `agent.py` or `app.py` in this step.
- **Manual edit required:**
  - Open `Dockerfile` at **line 37**.
  - Replace `CHANGE-ME` with your GitHub username or organization name.
  - GHCR uses this label to automatically link the container image to the repository.

---

## Ops Part

### Core Concepts (The Five Ideas)
1. **Tag vs. Digest:** A tag (`:0.2.0`) is a mutable pointer; a digest (`@sha256:...`) is an immutable cryptographic content hash. Everything critical (signing, verifying, deploying) must reference the digest.
2. **Signature:** Proves who built the image and guarantees it has not been modified. It is stored directly in the container registry alongside the image.
3. **SBOM (Software Bill of Materials):** The complete ingredient list—every package and version inside the image. Enables answering questions like *"Are we vulnerable to CVE-X?"* months later without rebuilding.
4. **Attestation:** A cryptographically signed statement about a specific digest (e.g., *"this SBOM accurately describes this exact image"*).
5. **Rekor:** Sigstore’s public transparency log. Default signing registers image names and digests here. In an enterprise/banking setup, teams use `--tlog-upload=false` or a private Rekor instance. For training, default settings are fine.

---

### Step-by-Step Execution

#### 1. Install Tools
```bash
# Install Cosign
curl -sfL -o cosign https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x cosign && sudo mv cosign /usr/local/bin/

# Install Syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin

# Verify installations
cosign version && syft version
```

---

#### 2. Initialize Git Repository
> **Note:** Run this before building the image to ensure key material ignore rules are active.

```bash
cd bank-agent
git init -b main
git add .
git status   # MUST NOT list .env. If it does, stop and check .gitignore!
git commit -m "Step 1-4: agent, HTTP wrapper, hardened image, release script"
```

Create an empty repository named `bank-agent` on GitHub (via web UI—do **not** initialize with README or `.gitignore` since they already exist locally), then run:

```bash
git remote add origin https://github.com/<OWNER>/bank-agent.git
git push -u origin main
```

---

#### 3. Generate Signing Keys
```bash
export COSIGN_PASSWORD='choose-a-passphrase'   # Encrypts the private key on disk
cosign generate-key-pair                       # Generates cosign.key (private) and cosign.pub (public)

git status                                     # cosign.key MUST be absent (ignored); cosign.pub must be present
git add cosign.pub && git commit -m "Add image signing public key" && git push
```

> `cosign.pub` is committed intentionally: verifiers (you now, Kyverno in Module 6) need it. `cosign.key` **never** leaves your local machine. In CI pipelines, signing will be keyless.

---

#### 4. GHCR Login
Create a classic Personal Access Token (PAT) with `write:packages` scope (**GitHub → Settings → Developer settings**). This is temporary for this step; CI will use its built-in token later.

```bash
export GHCR_TOKEN='ghp_…'
echo "$GHCR_TOKEN" | docker login ghcr.io -u <OWNER> --password-stdin
```

---

#### 5. Build, Push, and Resolve Digest
```bash
export OWNER=<owner-lowercase>
docker build -t ghcr.io/$OWNER/bank-agent:0.2.0 .
docker push ghcr.io/$OWNER/bank-agent:0.2.0

# Extract immutable digest
docker buildx imagetools inspect ghcr.io/$OWNER/bank-agent:0.2.0 --format '{{.Manifest.Digest}}'
export DIGEST=ghcr.io/$OWNER/bank-agent@sha256:<paste>
```

> **Registry visibility:** The package will show under **GitHub Profile → Packages** as private by default, linked via the Dockerfile label. Leave it private—Step 5 covers Image Pull Secrets needed for Kubernetes clusters.

---

#### 6. Sign and Verify Image
```bash
# Sign the image digest
cosign sign --key cosign.key -y $DIGEST

# Verify signature (JSON payload output = success; "no matching signatures" = failure)
cosign verify --key cosign.pub $DIGEST

# View signature tree
cosign tree $DIGEST
```

---

#### 7. Generate SBOM, Attest, and Verify
```bash
# Generate SBOM
syft docker:ghcr.io/$OWNER/bank-agent:0.2.0 -o spdx-json > sbom.spdx.json

# Attach signed attestation
cosign attest --key cosign.key --type spdxjson --predicate sbom.spdx.json -y $DIGEST

# Verify attestation
cosign verify-attestation --key cosign.pub --type spdxjson $DIGEST | head -c 300

# View updated tree (now displays signature + attestation)
cosign tree $DIGEST

# Scan SBOM offline (no container runtime or image required)
trivy sbom sbom.spdx.json
```

---

#### 8. Negative Test (Security Verification)
```bash
cosign verify --key cosign.pub python:3.12-slim
```
*Expected result:* **Fails** (image is unsigned by our key). This demonstrates the exact admission policy Kyverno will enforce cluster-wide in Module 6: **unsigned images will not be admitted.**

---

### Release Automation Script
The file `scripts/release.sh` bundles the above commands into a single automated pipeline, using `trivy --exit-code 1` to act as an automated security gate.

Test run the script end-to-end:
```bash
OWNER=$OWNER VERSION=0.2.1 ./scripts/release.sh
```

*(In Module 5, the CI workflow will replicate this step-by-step, replacing local keys with keyless OIDC signing).*

---

### Required Output Deliverables
Please paste back:
- [ ] `cosign tree` output
- [ ] The first line of `cosign verify`
- [ ] Package count from: `jq '.packages | length' sbom.spdx.json`
- [ ] The Trivy summary line

---

## Next Up: Step 5 (Module 3 Begins)
- **Raw Kubernetes Manifests:** `Namespace`, `imagePullSecret`, `Secret`, `ConfigMap`, `Deployment` (health probes, `securityContext`, resource limits/requests), `Service`.
- **Deployment targets:** Apply directly to Docker Desktop K8s, configure port-forwarding, test `/ready` endpoint.
- **Visual cluster management:** Headlamp or Portainer setup.