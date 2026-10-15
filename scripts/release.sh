#!/usr/bin/env bash
# bank-agent / Step 4 — build, scan, push, sign, SBOM, attest, verify.
# This is the exact sequence the CI pipeline runs in Module 5 (there with keyless signing via GitHub OIDC).
# Usage:  OWNER=<github-user-or-org, lowercase> VERSION=0.2.0 ./scripts/release.sh
# Needs:  docker, trivy, cosign, syft on PATH; `docker login ghcr.io` done; cosign.key/cosign.pub in the repo root.

# [OPS] the three safety belts of any ops script: stop on error, stop on unset variable, stop on a failure inside a pipe
set -euo pipefail

OWNER="sidd-harth"
VERSION="0.3.0"
IMAGE="ghcr.io/${OWNER}/bank-agent"
KEY="${COSIGN_KEY:-cosign.key}"   # private key: never committed, never in the image
PUB="${COSIGN_PUB:-cosign.pub}"   # public key: committed; Kyverno reads it in Module 6 to admit only images we signed

echo "==> 1/7 build ${IMAGE}:${VERSION}"
docker build -t "${IMAGE}:${VERSION}" .

echo "==> 2/7 scan: HIGH/CRITICAL with a fix available fails the release"
# [OPS] this one line is the vulnerability gate; CI runs the same command
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "${IMAGE}:${VERSION}"

echo "==> 3/7 push"
docker push "${IMAGE}:${VERSION}"

echo "==> 4/7 resolve the immutable digest: tags move, digests never do"
DIGEST_SHA="$(docker buildx imagetools inspect "${IMAGE}:${VERSION}" --format '{{.Manifest.Digest}}')"
DIGEST="${IMAGE}@${DIGEST_SHA}"
echo "    ${DIGEST}"

echo "==> 5/7 sign the digest (signature is stored in the registry next to the image)"
# [OPS] default uploads name+digest to the public Rekor transparency log. For a private bank image add:
#       --tlog-upload=false   (and verify with --insecure-ignore-tlog=true), or run a private Rekor.
cosign sign --key "${KEY}" -y "${DIGEST}"

echo "==> 6/7 SBOM (ingredient list) and attestation (signed SBOM bound to this exact digest)"
syft "docker:${IMAGE}:${VERSION}" -o spdx-json > sbom.spdx.json
cosign attest --key "${KEY}" --type spdxjson --predicate sbom.spdx.json -y "${DIGEST}"

echo "==> 7/7 verify: this is what the cluster will do before it runs the image"
cosign verify --key "${PUB}" "${DIGEST}" > /dev/null && echo "    signature OK"
cosign verify-attestation --key "${PUB}" --type spdxjson "${DIGEST}" > /dev/null && echo "    SBOM attestation OK"
echo "done: ${DIGEST}"