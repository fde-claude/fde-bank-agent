#!/usr/bin/env bash
# Step 16: CI pipeline (SHA-pinned Actions, checksum-verified scanners, keyless signing), the permanent test suite,
#          ruff/pytest/gitleaks/kube-linter configuration, Dependabot, runbook section.
#          The six Python files are re-shipped because `ruff format` reformatted them (whitespace only; ingest.py also
#          gained strict zip and lost two semicolon one-liners). CI enforces formatting from now on.
# Run from the repo root:  bash step16-files.sh      (or paste the blocks below into a terminal)
# Delimiter is quoted ('EOF') so ${VAR} and $(...) inside the files are written literally, not expanded.
set -euo pipefail
[ -f agent.py ] || { echo 'run this from the bank-agent repo root'; exit 1; }

mkdir -p ".github/workflows"
cat << 'EOF' > .github/workflows/ci.yaml
# .github/workflows/ci.yaml
# bank-agent CI: lint -> test -> secret scan -> manifest checks -> build, scan, sign, SBOM, push.
#
# [OPS] Supply-chain rules this file follows, learned from the LiteLLM compromise of March 2026 (a poisoned scanner
#       Action stole publishing tokens from a CI runner):
#   1. Every third-party Action is pinned to a full commit SHA, never a tag. The "# vN" comment is for humans and Dependabot.
#   2. Scanners (Trivy, Gitleaks, Syft, hadolint) are downloaded as release binaries and verified against the publisher's
#      checksums before they run. No mutable "latest", no Action in the trust path of a tool that sees the whole repo.
#   3. GITHUB_TOKEN permissions are read-only by default and widened per job only for what that job does.
#   4. Signing is keyless: the identity is this workflow's OIDC token, verifiable by anyone, nothing stored.
#   5. One build per branch at a time; superseded PR runs are cancelled.
name: ci

on:
  pull_request:
  push:
    branches: [main]
    paths-ignore: ["docs/**", "README.md"]      # documentation never needs an image; knowledge/ DOES (it ships in the image)
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

env:
  PYTHON_VERSION: "3.12"
  IMAGE: ghcr.io/${{ github.repository_owner }}/bank-agent
  TRIVY_VERSION: "0.76.0"
  GITLEAKS_VERSION: "8.30.1"
  SYFT_VERSION: "1.54.1"
  HADOLINT_VERSION: "2.15.1"
  HADOLINT_SHA256: "c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507"

jobs:
  lint:
    name: lint (ruff, hadolint)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
      - uses: actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97 # v7
        with:
          python-version: ${{ env.PYTHON_VERSION }}
      - name: ruff (lint + format check)
        run: |
          pip install --quiet ruff==0.17.1
          ruff check .
          ruff format --check .
      - name: hadolint (binary pinned by hash)
        run: |
          curl -sSfL -o hadolint "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64"
          echo "${HADOLINT_SHA256}  hadolint" | sha256sum -c -
          chmod +x hadolint && ./hadolint Dockerfile

  test:
    name: test (mocked LLM, real pgvector)
    runs-on: ubuntu-latest
    services:
      knowledge-db:
        image: pgvector/pgvector:pg16
        env:
          POSTGRES_USER: knowledge
          POSTGRES_PASSWORD: ci
          POSTGRES_DB: knowledge
        ports: ["5432:5432"]
        options: --health-cmd "pg_isready -U knowledge -d knowledge" --health-interval 5s --health-timeout 3s --health-retries 10
    env:
      ANTHROPIC_API_KEY: sk-test-not-a-real-key          # the fake model never calls out; the key only satisfies the client constructor
      KNOWLEDGE_DATABASE_URL: postgresql://knowledge:ci@localhost:5432/knowledge
      ANTHROPIC_BASE_URL: http://unused.invalid
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
      - uses: actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97 # v7
        with:
          python-version: ${{ env.PYTHON_VERSION }}
          cache: pip
      - run: pip install --quiet -r requirements.txt pytest==9.1.1
      - run: pytest

  secrets:
    name: secret scan (gitleaks, full history)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
        with:
          fetch-depth: 0                                 # a secret committed and then removed is still a leak
      - name: gitleaks (binary verified against release checksums)
        run: |
          curl -sSfL -o gitleaks.tgz "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
          curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_checksums.txt" | grep "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" | sed "s/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz/gitleaks.tgz/" | sha256sum -c -
          tar -xzf gitleaks.tgz gitleaks
          ./gitleaks git --config .gitleaks.toml --redact --exit-code 1 .

  manifests:
    name: manifests (helm lint, kube-linter)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
      - name: helm lint both charts, dev values
        run: |
          helm lint deploy/chart/bank-agent -f deploy/chart/bank-agent/values-dev.yaml
          helm lint deploy/chart/litellm -f deploy/chart/litellm/values-dev.yaml
      - uses: stackrox/kube-linter-action@87802a2f4e01abebb3ee3c67a3002fea71f6eae5 # v1
        with:
          directory: deploy
          config: .kube-linter.yaml

  build:
    name: build, scan, sign, SBOM, push
    needs: [lint, test, secrets, manifests]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write          # push to GHCR
      id-token: write          # keyless signing: the OIDC token IS the signing identity
    outputs:
      digest: ${{ steps.push.outputs.digest }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
      - uses: docker/setup-buildx-action@f87e5991a6d7451dcb8d9637bfbc97413f497069 # v4
      - name: image tags (git sha, and the chart's appVersion)
        id: meta
        uses: docker/metadata-action@dc802804100637a589fabce1cb79ff13a1411302 # v6
        with:
          images: ${{ env.IMAGE }}
          tags: |
            type=sha,prefix=sha-,format=short
            type=raw,value=${{ github.sha }}
      - name: build (local, not pushed yet)
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7
        with:
          context: .
          load: true
          tags: ${{ env.IMAGE }}:ci
          cache-from: type=gha
          cache-to: type=gha,mode=max
      - name: trivy (binary verified against release checksums)
        run: |
          curl -sSfL -o trivy.tgz "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
          curl -sSfL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt" | grep "trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" | sed "s/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz/trivy.tgz/" | sha256sum -c -
          tar -xzf trivy.tgz trivy
          # [OPS] the gate: HIGH/CRITICAL with a fix available fails the build. Unfixed base-image CVEs are reported, not blocking.
          ./trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "${IMAGE}:ci"
          ./trivy image --severity HIGH,CRITICAL --exit-code 0 --format table "${IMAGE}:ci" > trivy-full.txt
      - name: upload scan report
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7
        with:
          name: trivy-report
          path: trivy-full.txt
      - name: login to GHCR
        if: github.event_name != 'pull_request'
        uses: docker/login-action@dbcb813823bdd20940b903addbd779551569679f # v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}    # the job token, scoped to this repo's packages; no PAT anywhere
      - name: push
        if: github.event_name != 'pull_request'
        id: push
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
      - name: cosign (keyless) + SBOM attestation
        if: github.event_name != 'pull_request'
        uses: sigstore/cosign-installer@398d4b0eeef1380460a10c8013a76f728fb906ac # v3
      - name: sign the digest, attach the SBOM, verify
        if: github.event_name != 'pull_request'
        env:
          DIGEST: ${{ steps.push.outputs.digest }}
        run: |
          REF="${IMAGE}@${DIGEST}"
          cosign sign --yes "${REF}"
          curl -sSfL -o syft.tgz "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_amd64.tar.gz"
          curl -sSfL "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_checksums.txt" | grep "syft_${SYFT_VERSION}_linux_amd64.tar.gz" | sed "s/syft_${SYFT_VERSION}_linux_amd64.tar.gz/syft.tgz/" | sha256sum -c -
          tar -xzf syft.tgz syft
          ./syft "${REF}" -o spdx-json > sbom.spdx.json
          cosign attest --yes --type spdxjson --predicate sbom.spdx.json "${REF}"
          # [OPS] what every consumer (Kyverno in Module 6, your laptop, an auditor) can check without any key material:
          cosign verify "${REF}" \
            --certificate-identity-regexp "^https://github.com/${{ github.repository }}/.github/workflows/ci.yaml@refs/heads/main$" \
            --certificate-oidc-issuer https://token.actions.githubusercontent.com > /dev/null
          echo "signed and attested: ${REF}"
          {
            echo "### Image published"
            echo '```'
            echo "${REF}"
            echo "tags: ${{ steps.meta.outputs.tags }}"
            echo '```'
            echo "Signed keylessly by this workflow (Sigstore). Verify with cosign verify + the identity regexp above."
          } >> "$GITHUB_STEP_SUMMARY"
EOF
echo "wrote .github/workflows/ci.yaml"

mkdir -p ".github"
cat << 'EOF' > .github/dependabot.yml
# [OPS] the other half of pinning: pinned versions rot unless something proposes updates. Dependabot opens pull requests
#       for Actions (it understands SHA pins with version comments), pip pins and the Dockerfile base image.
#       Every proposal runs the full CI, including the eval gate from Step 17, before a human merges it.
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule: {interval: weekly}
  - package-ecosystem: pip
    directory: /
    schedule: {interval: weekly}
    groups:
      python-deps: {patterns: ["*"]}
  - package-ecosystem: docker
    directory: /
    schedule: {interval: weekly}
EOF
echo "wrote .github/dependabot.yml"

cat << 'EOF' > .kube-linter.yaml
# kube-linter configuration used by CI (manifests job) and locally: kube-linter lint deploy --config .kube-linter.yaml
checks:
  addAllBuiltIn: false
  doNotAutoAddDefaults: false
  exclude:
    # the netpol folder holds policy objects only; this check only applies to workloads anyway
    - "no-anti-affinity"   # single-replica stores (postgres, redis, ollama) are deliberately 1 replica in the lab
EOF
echo "wrote .kube-linter.yaml"

cat << 'EOF' > .gitleaks.toml
# gitleaks configuration: the default ruleset plus allow-listed placeholders.
[extend]
useDefault = true

[allowlist]
description = "documented placeholders that are not secrets"
paths = [
  '''\.env\.example$''',
  '''docs/.*\.md$''',          # runbooks show the SHAPE of keys (sk-..., pk-lf-...), never real ones
]
regexes = [
  '''REPLACE_ME''',
  '''sk-test-not-a-real-key''',
]
EOF
echo "wrote .gitleaks.toml"

cat << 'EOF' > pyproject.toml
# [OPS] Tool configuration for the checks CI runs. The same commands work on your laptop: ruff check . ; pytest
[tool.ruff]
line-length = 120
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "B", "UP"]   # errors, pyflakes, warnings, import order, bugbear, modernisation
ignore = ["E501"]                          # long lines are allowed where a comment explains an ops decision

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-q"
EOF
echo "wrote pyproject.toml"

cat << 'EOF' > .gitignore
# [OPS] first security control of the project: the secret never enters git.
.env
.venv/
__pycache__/
*.pyc

# [OPS] signing material and generated artifacts
cosign.key
sbom*.json

# tool caches
.pytest_cache/
.ruff_cache/
EOF
echo "wrote .gitignore"

mkdir -p "tests"
cat << 'EOF' > tests/conftest.py
"""
Shared fixtures. Every test runs offline: the Anthropic client is replaced by a scripted fake, Redis by an in-memory dict.
No API key, no network, no tokens spent. This is what "mocked-LLM unit tests" means in the CI pipeline.
"""

import os
import sys
import types
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-test-not-a-real-key")
os.environ.setdefault("ENABLE_RAG", "false")
os.environ.pop("LANGFUSE_PUBLIC_KEY", None)  # tracing off in tests
os.environ.pop("OTEL_EXPORTER_OTLP_ENDPOINT", None)

import agent  # noqa: E402
import memory  # noqa: E402

B = types.SimpleNamespace
USAGE = B(input_tokens=120, output_tokens=30, cache_read_input_tokens=100, cache_creation_input_tokens=0)


def tool_use(name, **inputs):
    return B(content=[B(type="tool_use", id="toolu_1", name=name, input=inputs)], stop_reason="tool_use", usage=USAGE)


def text(reply):
    return B(content=[B(type="text", text=reply)], stop_reason="end_turn", usage=USAGE)


class FakeRedis:
    def __init__(self):
        self.store, self.ttl = {}, {}

    def get(self, key):
        return self.store.get(key)

    def set(self, key, value, ex=None):
        self.store[key] = value
        self.ttl[key] = ex


@pytest.fixture
def fake_model():
    """fake_model(*responses) scripts the model's replies in order and records every request in .calls."""
    calls = []

    def script(*responses):
        calls.clear()
        it = iter(responses)

        def create(**kwargs):
            calls.append(kwargs)
            return next(it)

        agent.client.messages.create = create
        return calls

    script.calls = calls
    return script


@pytest.fixture
def fake_redis(monkeypatch):
    fake = FakeRedis()
    monkeypatch.setattr(memory, "_client", fake)
    return fake
EOF
echo "wrote tests/conftest.py"

mkdir -p "tests"
cat << 'EOF' > tests/test_agent_loop.py
"""The agent loop, tools and memory, exactly as exercised during Steps 1-15, now as a permanent regression suite."""

import json

import pytest
from conftest import text, tool_use
from prometheus_client import REGISTRY

import agent
import memory


def metric(name, **labels):
    return REGISTRY.get_sample_value(name, labels) or 0.0


def test_tool_round_trip_returns_final_text(fake_model):
    calls = fake_model(tool_use("get_account_balance", account_id="ACC-1001"), text("Balance is 25,430.50."))
    assert agent.run_agent("balance for ACC-1001?", request_id="r1") == "Balance is 25,430.50."
    assert len(calls) == 2
    result = calls[1]["messages"][2]["content"][0]
    assert result["type"] == "tool_result" and json.loads(result["content"])["balance"] == 25430.5


def test_every_call_carries_gateway_headers_and_alias(fake_model):
    calls = fake_model(text("hi"))
    agent.run_agent("hi", request_id="edge-42", session_id="s9")
    assert calls[0]["extra_headers"] == {
        "x-litellm-tags": "bank-agent",
        "x-litellm-trace-id": "edge-42",
        "x-litellm-session-id": "s9",
    }
    assert calls[0]["model"] == agent.MODEL


def test_loop_guard_stops_runaway_tool_loops(fake_model):
    before = metric("agent_loop_guard_total")
    fake_model(*[tool_use("get_account_balance", account_id="ACC-1001") for _ in range(10)])
    assert agent.run_agent("loop").startswith("Sorry")
    assert len(fake_model.calls) == agent.MAX_TURNS
    assert metric("agent_loop_guard_total") == before + 1


def test_unknown_account_is_a_business_result_not_a_failure():
    content, is_error = agent.run_tool("get_account_balance", {"account_id": "ACC-9999"})
    assert is_error is False and "error" in json.loads(content)


def test_tool_exception_becomes_error_result():
    content, is_error = agent.run_tool("get_recent_transactions", {"account_id": "ACC-1001", "bogus": 1})
    assert is_error is True and "TypeError" in content


def test_unknown_tool_is_rejected():
    assert agent.run_tool("no_such_tool", {}) == ('{"error": "unknown tool no_such_tool"}', True)


def test_action_tool_is_idempotent():
    agent.CHEQUE_REQUESTS.clear()
    first = json.loads(agent.request_cheque_book("ACC-1002", leaves=50))
    second = json.loads(agent.request_cheque_book("ACC-1002"))
    assert first["status"] == "requested" and second["status"] == "already_requested"
    assert first["reference"] == second["reference"] and first["reference"].startswith("CHQ-")


def test_transactions_limit_is_clamped():
    assert len(json.loads(agent.get_recent_transactions("ACC-1001", limit=99))["transactions"]) == 5
    assert len(json.loads(agent.get_recent_transactions("ACC-1001", limit=0))["transactions"]) == 1


def test_prompt_comes_from_file_with_cache_control():
    assert "customer-service assistant" in agent.SYSTEM_PROMPT
    assert agent.system_blocks()[0]["cache_control"] == {"type": "ephemeral"}


def test_memory_replays_history_and_trims_window(fake_model, fake_redis, monkeypatch):
    fake_model(text("first"))
    agent.run_agent("hello", session_id="s1")
    assert fake_redis.ttl["session:s1"] == memory.MEMORY_TTL
    calls = fake_model(text("second"))
    agent.run_agent("again", session_id="s1")
    assert [m["content"] for m in calls[0]["messages"]] == ["hello", "first", "again"]
    monkeypatch.setattr(memory, "MEMORY_TURNS", 2)
    for i in range(5):
        fake_model(text(f"r{i}"))
        agent.run_agent(f"m{i}", session_id="s2")
    history = json.loads(fake_redis.store["session:s2"])
    assert len(history) == 4 and history[0]["content"] == "m3"


def test_memory_outage_degrades_to_stateless(fake_model, monkeypatch):
    import redis

    class Broken:
        def get(self, k):
            raise redis.ConnectionError("down")

        def set(self, k, v, ex=None):
            raise redis.ConnectionError("down")

    monkeypatch.setattr(memory, "_client", Broken())
    fake_model(text("still answering"))
    assert agent.run_agent("hi", session_id="s3") == "still answering"


def test_token_metrics_are_recorded(fake_model):
    before = metric("agent_tokens_total", model=agent.MODEL, kind="cache_read")
    fake_model(text("ok"))
    agent.run_agent("x")
    assert metric("agent_tokens_total", model=agent.MODEL, kind="cache_read") == before + 100


@pytest.mark.parametrize("field", ["input_tokens", "output_tokens"])
def test_usage_without_cache_fields_is_tolerated(fake_model, field):
    from conftest import B

    fake_model(B(content=[B(type="text", text="ok")], stop_reason="end_turn", usage=B(**{field: 3})))
    assert agent.run_agent("x") == "ok"
EOF
echo "wrote tests/test_agent_loop.py"

mkdir -p "tests"
cat << 'EOF' > tests/test_app.py
"""The HTTP surface: probes, validation, request ids, metrics, provider failure handling."""

import anthropic
import httpx2
import pytest
from conftest import text
from fastapi.testclient import TestClient

import agent
import app as appmod


@pytest.fixture
def client():
    return TestClient(appmod.app)


def test_probes(client):
    assert client.get("/health").json() == {"status": "ok"}
    assert client.get("/ready").json()["model"] == agent.MODEL


def test_chat_echoes_request_id_and_forwards_it(client, fake_model):
    calls = fake_model(text("hello"))
    r = client.post("/chat", json={"message": "hi"}, headers={"x-request-id": "edge-77"})
    assert r.status_code == 200 and r.json()["reply"] == "hello"
    assert r.headers["x-request-id"] == "edge-77" and calls[0]["extra_headers"]["x-litellm-trace-id"] == "edge-77"


def test_minted_request_id_when_edge_sends_none(client, fake_model):
    calls = fake_model(text("hello"))
    r = client.post("/chat", json={"message": "hi"})
    assert (
        len(r.headers["x-request-id"]) == 36
        and calls[0]["extra_headers"]["x-litellm-trace-id"] == r.headers["x-request-id"]
    )


@pytest.mark.parametrize(
    "body", [{"message": ""}, {"message": "x" * 2001}, {"msg": "wrong"}, {"message": "hi", "session_id": "bad id!"}]
)
def test_validation_rejects_before_any_model_call(client, fake_model, body):
    fake_model()
    assert client.post("/chat", json=body).status_code == 422 and fake_model.calls == []


def test_provider_failure_is_a_generic_502(client):
    def boom(**kwargs):
        raise anthropic.APIConnectionError(request=httpx2.Request("POST", "https://api.anthropic.com/v1/messages"))

    agent.client.messages.create = boom
    r = client.post("/chat", json={"message": "hi"})
    assert r.status_code == 502 and "unavailable" in r.json()["error"]


def test_metrics_exposed_and_scrape_not_counted(client, fake_model):
    fake_model(text("hi"))
    client.post("/chat", json={"message": "hi"})
    body = client.get("/metrics").text
    assert "http_requests_total" in body and "agent_model_calls_total" in body and 'path="/metrics"' not in body


def test_readiness_fails_closed_without_key(client, monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY")
    assert client.get("/ready").status_code == 503 and client.get("/health").status_code == 200
EOF
echo "wrote tests/test_app.py"

mkdir -p "tests"
cat << 'EOF' > tests/test_ingest.py
"""Knowledge-base ingestion. Parsing and chunking run anywhere; the database tests run when KNOWLEDGE_DATABASE_URL points
at a Postgres with pgvector (CI starts one as a service container) and are skipped otherwise."""

import hashlib
import math
import os

import pytest

import ingest
import rag

KNOWLEDGE_DIR = ingest.KNOWLEDGE_DIR


def fake_embed(texts, kind="query"):
    """Deterministic bag-of-words vectors: enough to exercise SQL, idempotency and filters without a model."""
    out = []
    for t in texts:
        v = [0.0] * 768
        for w in t.lower().replace(",", " ").replace(".", " ").split():
            v[int(hashlib.md5(w.encode()).hexdigest(), 16) % 768] += 1.0
        n = math.sqrt(sum(x * x for x in v)) or 1.0
        out.append([x / n for x in v])
    return out


def test_front_matter_and_sections():
    meta, body = ingest.parse_front_matter((KNOWLEDGE_DIR / "transfer-limits-and-charges.md").read_text())
    assert meta["audience"] == "customer" and meta["effective_date"] == "2026-09-01"
    sections = ingest.split_sections(body)
    assert [s for s, _ in sections][:2] == ["Overview", "Daily transfer limits"]
    assert all(len(t) <= ingest.MAX_CHARS for _, t in sections)


def test_every_document_has_metadata_and_a_staff_doc_exists():
    chunks = ingest.load_chunks(KNOWLEDGE_DIR)
    docs = {c["doc"] for c in chunks}
    assert len(docs) == 5 and 20 <= len(chunks) <= 40
    assert {c["audience"] for c in chunks} == {"customer", "staff"}
    assert all(c["effective_date"] and c["title"] for c in chunks)


def test_chunk_ids_change_only_when_content_changes():
    a = {c["id"]: c["content"] for c in ingest.load_chunks(KNOWLEDGE_DIR)}
    b = {c["id"]: c["content"] for c in ingest.load_chunks(KNOWLEDGE_DIR)}
    assert a == b


needs_db = pytest.mark.skipif(not os.getenv("KNOWLEDGE_DATABASE_URL"), reason="needs Postgres with pgvector")


@needs_db
def test_ingest_is_idempotent_and_filters_by_audience(monkeypatch):
    calls = {"n": 0}

    def counting(texts, kind="query"):
        calls["n"] += len(texts)
        return fake_embed(texts, kind)

    monkeypatch.setattr(rag, "embed", counting)
    assert ingest.main() == 0
    first = calls["n"]
    assert first >= 20
    assert ingest.main() == 0 and calls["n"] == first  # nothing re-embedded
    customer = rag.search("escalation tiers CS-FRAUD goodwill", audience="customer")
    staff = rag.search("escalation tiers CS-FRAUD goodwill", audience="staff")
    assert all("Escalation" not in r["document"] for r in customer["results"])
    assert staff["results"] and staff["results"][0]["document"].startswith("Internal Escalation")


@needs_db
def test_model_change_forces_full_reindex(monkeypatch):
    monkeypatch.setattr(rag, "embed", fake_embed)
    ingest.main()
    monkeypatch.setattr(rag, "EMBED_MODEL", "other-embeddings")
    calls = {"n": 0}

    def counting(texts, kind="query"):
        calls["n"] += len(texts)
        return fake_embed(texts, kind)

    monkeypatch.setattr(rag, "embed", counting)
    ingest.main()
    assert calls["n"] == len(ingest.load_chunks(KNOWLEDGE_DIR))
EOF
echo "wrote tests/test_ingest.py"

cat << 'EOF' > agent.py
"""
bank-agent / Step 1 — the smallest useful Claude agent.
One model-call loop, one mock tool, no framework.

Lines tagged [OPS] are platform-team knobs: they become env vars,
ConfigMaps, Secrets or gateway settings later. Lines tagged DEV are
app-team territory (prompt, tools, business logic).
"""

import hashlib
import json
import os
import sys
from pathlib import Path

import anthropic
from dotenv import load_dotenv
from prometheus_client import Counter, Histogram

import memory  # Step 12: conversation memory (Redis), see memory.py
import rag  # Step 13: retrieval over the knowledge base, see rag.py
import telemetry  # Step 15: traces, see telemetry.py

load_dotenv()  # [OPS] local only: copies .env into env vars. In K8s, Secrets/ConfigMaps do this job.

MODEL = os.getenv("MODEL_ID", "claude-haiku-5-5")  # [OPS] pinned model = image tag. Override via env, never edit code.
MAX_TURNS = 5  # [OPS] loop guard: hard cap on model calls per request (cost circuit breaker).

# [OPS] the SDK reads ANTHROPIC_API_KEY and ANTHROPIC_BASE_URL from the environment on its own. Pointing the app at the
#       gateway is therefore pure configuration: base URL = LiteLLM, key = a virtual key. Retries default to 2 for the
#       laptop (direct to Anthropic) and are set to 0 behind the gateway, which owns retries and fallback from Step 10 on.
client = anthropic.Anthropic(timeout=60.0, max_retries=int(os.getenv("SDK_MAX_RETRIES", "2")))


def gateway_headers(request_id: str, session_id: str = "") -> dict:
    # [OPS] Step 10: correlation and attribution for the gateway. The trace id joins edge -> app -> gateway logs into one
    #       chain; the tag makes spend queryable per workload in the admin UI. Ignored when talking to Anthropic directly.
    #       Step 15: the session id groups a whole conversation in the gateway's logs and in Langfuse.
    headers = {"x-litellm-tags": os.getenv("GATEWAY_TAG", "bank-agent")}
    if request_id:
        headers["x-litellm-trace-id"] = request_id
    if session_id:
        headers["x-litellm-session-id"] = session_id
    return headers


# [OPS] Step 15: the GenAI metrics. HTTP metrics (app.py) say the service is slow or failing; these say why:
#       how many model calls per request, how they ended, what they cost in tokens, whether the cache helped,
#       whether tools failed, whether retrieval found anything. Scraped with the rest of /metrics.
MODEL_CALLS = Counter("agent_model_calls_total", "Model calls by alias and stop reason", ["model", "stop_reason"])
TOKENS = Counter(
    "agent_tokens_total", "Tokens by alias and kind (input, output, cache_read, cache_creation)", ["model", "kind"]
)
TURNS = Histogram("agent_turns_per_request", "Model calls needed to answer one request", buckets=(1, 2, 3, 4, 5, 6))
TOOL_CALLS = Counter("agent_tool_calls_total", "Tool executions by tool and outcome", ["tool", "is_error"])
LOOP_GUARD = Counter("agent_loop_guard_total", "Requests stopped by MAX_TURNS")
RAG_SEARCHES = Counter("agent_rag_searches_total", "Knowledge-base searches by confidence", ["low_confidence"])


def record_usage(response) -> None:
    """Token counters from the response's usage block; every field is optional, so missing ones count as zero."""
    usage = getattr(response, "usage", None)
    for kind, attr in (
        ("input", "input_tokens"),
        ("output", "output_tokens"),
        ("cache_read", "cache_read_input_tokens"),
        ("cache_creation", "cache_creation_input_tokens"),
    ):
        TOKENS.labels(MODEL, kind).inc(getattr(usage, attr, 0) or 0)
    MODEL_CALLS.labels(MODEL, str(response.stop_reason)).inc()


# [OPS] Step 12, slice 5: the prompt is a versioned file, not a string in code. Reviewed in pull requests, tested by the
#       eval gate (Step 17), baked into the image, and overridable per environment by mounting a different file.
PROMPT_FILE = os.getenv("PROMPT_FILE", str(Path(__file__).with_name("prompts") / "system.md"))
SYSTEM_PROMPT = Path(PROMPT_FILE).read_text().strip()
PROMPT_CACHE = (
    os.getenv("PROMPT_CACHE", "true").lower() == "true"
)  # [OPS] Anthropic prompt caching on the static prefix


def system_blocks() -> list:
    # The tools and this text form the static prefix of every call. With cache_control the provider stores that prefix
    # and charges a fraction for re-reading it. It only engages once the prefix exceeds the model's minimum cacheable
    # length, so the effect shows in the gateway logs when the prompt grows (Step 13 adds the knowledge base).
    block = {"type": "text", "text": SYSTEM_PROMPT}
    if PROMPT_CACHE:
        block["cache_control"] = {"type": "ephemeral"}
    return [block]


# ---- DEV: mock tools standing in for core-banking API calls (slice 6 moves them into an MCP server) ----
MOCK_ACCOUNTS = {"ACC-1001": 25430.50, "ACC-1002": 980.00}
MOCK_TRANSACTIONS = {
    "ACC-1001": [
        {"date": "2026-10-12", "amount": -1250.00, "memo": "Grocery Mart"},
        {"date": "2026-10-10", "amount": -89.99, "memo": "Streaming subscription"},
        {"date": "2026-10-08", "amount": 48000.00, "memo": "Salary credit"},
        {"date": "2026-10-05", "amount": -3200.00, "memo": "Electricity bill"},
        {"date": "2026-10-01", "amount": -15000.00, "memo": "Rent transfer"},
    ],
    "ACC-1002": [
        {"date": "2026-10-11", "amount": -20.00, "memo": "Coffee"},
        {"date": "2026-10-02", "amount": 1000.00, "memo": "Transfer from savings"},
    ],
}
# DEV: in-memory stand-in for the request ledger: one open request per account. [OPS] per pod, so two replicas do not
#      share it; the real ledger must be a shared store (slice 6 moves it into the MCP server, backed by a database).
CHEQUE_REQUESTS: dict = {}


def get_account_balance(account_id: str) -> str:
    balance = MOCK_ACCOUNTS.get(account_id)
    if balance is None:
        return json.dumps({"error": f"account {account_id} not found"})
    return json.dumps({"account_id": account_id, "balance": balance})


def get_recent_transactions(account_id: str, limit: int = 5) -> str:
    if account_id not in MOCK_TRANSACTIONS:
        return json.dumps({"error": f"account {account_id} not found"})
    return json.dumps(
        {"account_id": account_id, "transactions": MOCK_TRANSACTIONS[account_id][: max(1, min(limit, 20))]}
    )


def request_cheque_book(account_id: str, leaves: int = 25) -> str:
    # An ACTION tool: it changes the world, so it must be idempotent. A retry (by the model, the SDK, or the gateway)
    # must never issue a second cheque book. [OPS] duplicate-action prevention lives here, at the tool, not in the prompt.
    if account_id not in MOCK_ACCOUNTS:
        return json.dumps({"error": f"account {account_id} not found"})
    existing = CHEQUE_REQUESTS.get(account_id)
    if existing:
        return json.dumps({"status": "already_requested", **existing})
    ref = "CHQ-" + hashlib.sha256(account_id.encode()).hexdigest()[:6].upper()  # deterministic, same on every pod
    CHEQUE_REQUESTS[account_id] = {"reference": ref, "leaves": leaves, "delivery": "7 working days"}
    return json.dumps({"status": "requested", **CHEQUE_REQUESTS[account_id]})


ACCOUNT_ID = {"type": "string", "description": "Account ID, e.g. ACC-1001"}
TOOLS = [  # DEV: the tools' contracts (JSON Schema). This is all the model ever sees of them. Versioned in CI (Step 17).
    {
        "name": "get_account_balance",
        "description": "Return the current balance of a customer's account.",
        "input_schema": {"type": "object", "properties": {"account_id": ACCOUNT_ID}, "required": ["account_id"]},
    },
    {
        "name": "get_recent_transactions",
        "description": "Return the most recent transactions of an account, newest first.",
        "input_schema": {
            "type": "object",
            "properties": {
                "account_id": ACCOUNT_ID,
                "limit": {"type": "integer", "description": "How many, 1-20. Default 5."},
            },
            "required": ["account_id"],
        },
    },
    {
        "name": "request_cheque_book",
        "description": "Order a new cheque book for an account. An action: call only after the customer confirmed.",
        "input_schema": {
            "type": "object",
            "properties": {
                "account_id": ACCOUNT_ID,
                "leaves": {"type": "integer", "description": "25 or 50. Default 25."},
            },
            "required": ["account_id"],
        },
    },
]
TOOL_FUNCTIONS = {  # DEV: route table, tool name -> Python function.
    "get_account_balance": get_account_balance,
    "get_recent_transactions": get_recent_transactions,
    "request_cheque_book": request_cheque_book,
}

# ---- Step 13, slice 9: the knowledge base as a tool. Switchable: ENABLE_RAG=false removes it from the model's view ----
ENABLE_RAG = (
    os.getenv("ENABLE_RAG", "false").lower() == "true"
)  # [OPS] needs KNOWLEDGE_DATABASE_URL and the bank-embeddings alias
RAG_AUDIENCE = os.getenv(
    "RAG_AUDIENCE", "customer"
)  # [OPS] fixed per deployment for now; Step 21 derives it from identity


def search_bank_faq(question: str) -> str:
    # Retrieval is filtered by audience in SQL: a staff-only chunk cannot reach a customer conversation, whatever the prompt says.
    result = rag.search(question, audience=RAG_AUDIENCE)
    RAG_SEARCHES.labels(
        str(result["low_confidence"]).lower()
    ).inc()  # [OPS] a rising low-confidence rate = the knowledge base has a gap
    return json.dumps(result)


if ENABLE_RAG:
    TOOLS.append(
        {
            "name": "search_bank_faq",
            "description": "Search the bank's policies for limits, charges, timelines and procedures. "
            "Use for any question about how the bank works, not for a customer's own account data.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "question": {"type": "string", "description": "The customer's question, in their words"}
                },
                "required": ["question"],
            },
        }
    )
    TOOL_FUNCTIONS["search_bank_faq"] = search_bank_faq


def run_tool(name: str, args: dict) -> tuple[str, bool]:
    """Execute one tool call. Failures become data the model can read, never exceptions that kill the request."""
    fn = TOOL_FUNCTIONS.get(name)
    if fn is None:
        return json.dumps({"error": f"unknown tool {name}"}), True
    try:
        return fn(**args), False
    except Exception as exc:  # [OPS] a failing backend is reported as an error result (and counted later), not a 500
        return json.dumps({"error": f"{type(exc).__name__}: {exc}"}), True


# ---- The agent loop: call model -> run requested tools -> repeat until a final answer ----
def run_agent(user_message: str, request_id: str = "", session_id: str = "") -> str:
    history = memory.load(session_id)  # Step 12: earlier turns of this session, [] when stateless
    messages = history + [{"role": "user", "content": user_message}]
    with telemetry.span(
        "agent.run", **{"request.id": request_id, "session.id": session_id, "gen_ai.request.model": MODEL}
    ):
        for turn in range(1, MAX_TURNS + 1):
            # Step 15: one span per model call, with the OpenTelemetry GenAI attributes Langfuse understands
            with telemetry.span(
                "gen_ai.chat", **{"gen_ai.system": "anthropic", "gen_ai.request.model": MODEL, "agent.turn": turn}
            ) as sp:
                response = client.messages.create(  # one HTTPS call to the model (via the gateway from Step 10) per iteration
                    model=MODEL,
                    max_tokens=1024,  # [OPS] output ceiling per call (thinking tokens count too); bounds cost and latency.
                    system=system_blocks(),
                    tools=TOOLS,
                    messages=messages,
                    extra_headers=gateway_headers(request_id, session_id),
                )
                record_usage(response)
                if sp is not None:
                    usage = getattr(response, "usage", None)
                    sp.set_attribute("gen_ai.response.finish_reasons", [str(response.stop_reason)])
                    sp.set_attribute("gen_ai.usage.input_tokens", getattr(usage, "input_tokens", 0) or 0)
                    sp.set_attribute("gen_ai.usage.output_tokens", getattr(usage, "output_tokens", 0) or 0)
            if response.stop_reason != "tool_use":  # no tool requested -> this is the final answer
                TURNS.observe(turn)
                text = "".join(b.text for b in response.content if b.type == "text")
                reply = text or f"[no text returned, stop_reason={response.stop_reason}]"
                memory.save(
                    session_id, history, user_message, reply
                )  # Step 12: remember this exchange (no-op when stateless)
                return reply
            messages.append(
                {"role": "assistant", "content": response.content}
            )  # keep the model's turn (incl. tool request)
            results = []
            for b in response.content:
                if b.type == "tool_use":
                    with telemetry.span(f"tool {b.name}", **{"tool.name": b.name}) as ts:
                        content, is_error = run_tool(b.name, b.input)
                        if ts is not None:
                            ts.set_attribute("tool.is_error", is_error)
                    TOOL_CALLS.labels(b.name, str(is_error).lower()).inc()
                    results.append(
                        {"type": "tool_result", "tool_use_id": b.id, "content": content, "is_error": is_error}
                    )
            messages.append({"role": "user", "content": results})  # tool output goes back as the next user turn
        TURNS.observe(MAX_TURNS)
        LOOP_GUARD.inc()  # [OPS] alert on this: a model stuck in a loop costs money every iteration
    return "Sorry, I could not complete that request."  # [OPS] loop guard tripped


if __name__ == "__main__":
    question = " ".join(sys.argv[1:]) or "What's the balance on account ACC-1001?"
    print(run_agent(question))
EOF
echo "wrote agent.py"

cat << 'EOF' > app.py
"""
bank-agent / Step 2 — HTTP wrapper around the Step 1 agent.

agent.py is untouched. This file only adds the service surface Kubernetes needs:
  POST /chat    the business endpoint
  GET  /health  liveness:  is the process alive?           (never calls the model)
  GET  /ready   readiness: can this pod take traffic yet?   (never calls the model)

Run locally:  uvicorn app:app --reload --port 8000
"""

import logging
import os
import time
import uuid

import anthropic
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from prometheus_client import Counter, Gauge, Histogram, make_asgi_app
from pydantic import BaseModel, Field

import telemetry  # Step 15: optional tracing; a no-op unless configured
from agent import MODEL, run_agent  # DEV: the Step 1 loop, reused as-is

logging.basicConfig(  # [OPS] log level via env; one line per event, parseable by any log shipper
    level=os.getenv("LOG_LEVEL", "INFO"), format="%(asctime)s %(levelname)s %(message)s"
)
log = logging.getLogger("bank-agent")

app = FastAPI(title="bank-agent", version="0.7.0")  # version shows in /docs; later it comes from the image tag

# [OPS] Step 8: the three metrics every HTTP service should export. Scraped in-cluster by Prometheus via /metrics;
#       the north gateway never publishes that path. Route paths are static here, so they are safe as label values.
REQUESTS = Counter("http_requests_total", "Requests by method, path and status", ["method", "path", "status"])
IN_FLIGHT = Gauge(
    "http_requests_in_flight", "Requests being handled right now", ["path"]
)  # [OPS] the autoscaling signal
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Request latency in seconds",
    ["path"],
    buckets=(0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60, 120, 180),  # [OPS] top bucket = the gateway read timeout
)
app.mount("/metrics", make_asgi_app())
telemetry.instrument_fastapi(app)  # Step 15: one server span per request (probes and scrapes excluded)


class ChatRequest(
    BaseModel
):  # DEV: the request contract. Validation is automatic: bad input -> 422, never reaches the model
    message: str = Field(
        min_length=1, max_length=2000
    )  # [OPS] input ceiling: bounds tokens per request (cost + abuse control)
    # Step 12: an opaque conversation handle chosen by the client. Letters, digits, - and _ only: it becomes a Redis key.
    session_id: str | None = Field(default=None, min_length=1, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")


class ChatReply(BaseModel):
    reply: str
    model: str


@app.middleware("http")
async def access_log(request: Request, call_next):
    # [OPS] one structured access-log line per request: id, route, status, latency. Never the message body (PII).
    path = request.url.path
    if path.startswith("/metrics"):  # the scrape itself is not traffic
        return await call_next(request)
    request_id = request.headers.get("x-request-id") or str(uuid.uuid4())  # honour the edge's ID, else mint one
    request.state.request_id = request_id  # Step 10: make it available to the route, which forwards it to the gateway
    start = time.perf_counter()
    IN_FLIGHT.labels(path).inc()
    try:
        response = await call_next(request)
    finally:
        IN_FLIGHT.labels(path).dec()  # [OPS] decremented even on failure, or the gauge would drift upward forever
    elapsed = time.perf_counter() - start
    LATENCY.labels(path).observe(elapsed)
    REQUESTS.labels(request.method, path, str(response.status_code)).inc()
    response.headers["x-request-id"] = request_id  # echo it back so client, gateway and app logs can be joined
    log.info(
        "request_id=%s method=%s path=%s status=%s latency_ms=%.0f",
        request_id,
        request.method,
        path,
        response.status_code,
        elapsed * 1000,
    )
    return response


@app.exception_handler(anthropic.APIError)
async def upstream_error(request: Request, exc: anthropic.APIError):
    # [OPS] provider failure -> 502 with a generic body. Details go to logs, never to the customer.
    log.error("upstream_error type=%s status=%s", type(exc).__name__, getattr(exc, "status_code", "n/a"))
    return JSONResponse(status_code=502, content={"error": "The assistant is temporarily unavailable."})


@app.get("/health")
def health():
    # Liveness: the process is up. Must NOT depend on the provider, or a provider outage crash-loops the whole fleet.
    return {"status": "ok"}


@app.get("/ready")
def ready():
    # Readiness: config is present. A 503 pulls the pod out of the Service without restarting it.
    if not os.getenv("ANTHROPIC_API_KEY"):
        return JSONResponse(status_code=503, content={"status": "not ready", "reason": "ANTHROPIC_API_KEY missing"})
    return {"status": "ready", "model": MODEL}


@app.post("/chat", response_model=ChatReply)
def chat(body: ChatRequest, request: Request):
    # Plain `def`, not `async def`, on purpose: the SDK call blocks, so FastAPI runs it in a worker thread
    # and the event loop stays free to answer probes. The thread pool size is this pod's concurrency ceiling.
    reply = run_agent(body.message, request_id=request.state.request_id, session_id=body.session_id or "")
    return ChatReply(reply=reply, model=MODEL)
EOF
echo "wrote app.py"

cat << 'EOF' > memory.py
"""
bank-agent / Step 12, slice 4 — conversation memory.

The model remembers nothing between calls; the API is stateless. Memory is therefore OUR state, and state is an
ops concern: where it lives (Redis), how much we keep (a sliding window of turns), how long (a TTL), and what
happens when the store is unavailable (the agent keeps working, without memory).

Stored per session: plain text turns only, user and assistant. Tool calls and results are not stored; they would make
the history large and fragile, and the final answer already contains what mattered.
"""

import json
import logging
import os

import redis

log = logging.getLogger("bank-agent.memory")

REDIS_URL = os.getenv(
    "REDIS_URL", ""
)  # [OPS] empty = memory disabled (CLI, tests). redis://host:6379/1 in Compose and K8s
MEMORY_TURNS = int(
    os.getenv("MEMORY_TURNS", "10")
)  # [OPS] sliding window: last N user/assistant pairs. Bounds tokens per request.
MEMORY_TTL = int(
    os.getenv("MEMORY_TTL_SECONDS", "1800")
)  # [OPS] sessions expire after 30 min of silence. Nothing lingers forever.

_client = redis.Redis.from_url(REDIS_URL, socket_timeout=0.5, socket_connect_timeout=0.5) if REDIS_URL else None


def _key(session_id: str) -> str:
    return f"session:{session_id}"  # [OPS] key prefix: lets you count, inspect and wipe sessions as one group in RedisInsight


def load(session_id: str) -> list:
    """Previous turns for this session, or [] when there is no session, no store, or the store is unreachable."""
    if not (_client and session_id):
        return []
    try:
        raw = _client.get(_key(session_id))
        return json.loads(raw) if raw else []
    except redis.RedisError as exc:  # [OPS] graceful degradation: a memory outage must not become a chat outage
        log.warning("memory unavailable, continuing stateless: %s", type(exc).__name__)
        return []


def save(session_id: str, history: list, user_message: str, assistant_reply: str) -> None:
    """Append this exchange, trim to the window, reset the TTL."""
    if not (_client and session_id):
        return
    turns = history + [{"role": "user", "content": user_message}, {"role": "assistant", "content": assistant_reply}]
    turns = turns[-2 * MEMORY_TURNS :]  # keep whole pairs; the oldest fall off the window
    try:
        _client.set(_key(session_id), json.dumps(turns), ex=MEMORY_TTL)
    except redis.RedisError as exc:
        log.warning("memory not saved: %s", type(exc).__name__)
EOF
echo "wrote memory.py"

cat << 'EOF' > rag.py
"""
bank-agent / Step 13, slice 9 — retrieval over the bank's knowledge base.

Two pieces, both deliberately small:
  embed(texts)              -> vectors, via the gateway's OpenAI-compatible /v1/embeddings endpoint (alias bank-embeddings)
  search(question, audience) -> the k most similar chunks, filtered by audience IN SQL

The index itself is built by ingest.py. This module only reads it.
"""

import json
import os
import urllib.request

import psycopg

# [OPS] the same gateway and key the agent already uses; embeddings are just another model behind an alias
EMBED_BASE_URL = os.getenv("EMBED_BASE_URL") or os.getenv("ANTHROPIC_BASE_URL", "")
EMBED_API_KEY = os.getenv("EMBED_API_KEY") or os.getenv("ANTHROPIC_API_KEY", "")
EMBED_MODEL = os.getenv("EMBED_MODEL", "bank-embeddings")
KNOWLEDGE_DATABASE_URL = os.getenv(
    "KNOWLEDGE_DATABASE_URL", ""
)  # [OPS] its own database, never the gateway's Tier-0 one
RAG_TOP_K = int(os.getenv("RAG_TOP_K", "3"))
RAG_MIN_SCORE = float(os.getenv("RAG_MIN_SCORE", "0.45"))  # cosine similarity below this = "probably not an answer"


def embed(texts: list, kind: str = "query") -> list:
    """Vectors for a list of texts. nomic-embed-text expects a task prefix; documents and queries get different ones."""
    prefix = "search_query: " if kind == "query" else "search_document: "
    body = json.dumps({"model": EMBED_MODEL, "input": [prefix + t for t in texts]}).encode()
    req = urllib.request.Request(
        f"{EMBED_BASE_URL.rstrip('/')}/v1/embeddings",
        data=body,
        method="POST",
        headers={"content-type": "application/json", "authorization": f"Bearer {EMBED_API_KEY}"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:  # [OPS] bounded like every other outbound call
        data = json.load(resp)
    return [item["embedding"] for item in sorted(data["data"], key=lambda d: d["index"])]


def to_pgvector(vec: list) -> str:
    """pgvector accepts the text form '[0.1,0.2,...]'; no extra client library needed."""
    return "[" + ",".join(f"{x:.6f}" for x in vec) + "]"


def search(question: str, audience: str, k: int = RAG_TOP_K) -> dict:
    """Top-k chunks for this audience, with cosine similarity scores. The audience filter is SQL, not a prompt instruction."""
    qvec = to_pgvector(embed([question], kind="query")[0])
    sql = """
        SELECT title, section, content, effective_date, 1 - (embedding <=> %s::vector) AS score
        FROM chunks
        WHERE audience = %s
        ORDER BY embedding <=> %s::vector
        LIMIT %s
    """
    with psycopg.connect(KNOWLEDGE_DATABASE_URL, connect_timeout=5) as conn:
        rows = conn.execute(sql, (qvec, audience, qvec, k)).fetchall()
    results = [
        {
            "document": title,
            "section": section,
            "effective_date": str(eff),
            "score": round(float(score), 3),
            "excerpt": content,
        }
        for title, section, content, eff, score in rows
    ]
    return {
        "results": results,
        "low_confidence": not results
        or results[0]["score"] < RAG_MIN_SCORE,  # the model is told when to say "not found"
    }
EOF
echo "wrote rag.py"

cat << 'EOF' > ingest.py
"""
bank-agent / Step 13 — build the knowledge index.

knowledge/*.md  ->  front matter + sections  ->  chunks  ->  embeddings via the gateway  ->  pgvector

Run as a one-off (first load) and on a schedule (freshness). It is idempotent:
  - a chunk's id is the hash of its document, section and text: unchanged chunks are skipped, changed ones re-embedded
  - chunks whose source disappeared are deleted
  - the embedding model and dimension are recorded; a change forces a full re-index instead of mixing vectors

Env: KNOWLEDGE_DIR (default knowledge/), KNOWLEDGE_DATABASE_URL, EMBED_* (see rag.py), EMBED_DIM (768), GIT_SHA (optional)
"""

import hashlib
import json
import logging
import os
import sys
from pathlib import Path

import psycopg

import rag

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("bank-agent.ingest")

KNOWLEDGE_DIR = Path(os.getenv("KNOWLEDGE_DIR", str(Path(__file__).with_name("knowledge"))))
EMBED_DIM = int(os.getenv("EMBED_DIM", "768"))  # nomic-embed-text; the index is created with this dimension
MAX_CHARS = 1500  # a section longer than this is split on paragraph boundaries
BATCH = 16


def parse_front_matter(text: str) -> tuple[dict, str]:
    """'---\\nkey: value\\n---\\nbody' -> ({key: value}, body). Flat keys only, on purpose."""
    if not text.startswith("---"):
        return {}, text
    _, fm, body = text.split("---", 2)
    meta = {}
    for line in fm.strip().splitlines():
        key, _, value = line.partition(":")
        meta[key.strip()] = value.strip()
    return meta, body


def split_sections(body: str) -> list:
    """One chunk per '## ' heading (text before the first heading becomes 'Overview'); long sections split by paragraph."""
    sections, current, title = [], [], "Overview"
    for line in body.splitlines():
        if line.startswith("# "):
            continue  # the H1 is the document title, already in front matter
        if line.startswith("## "):
            if "".join(current).strip():
                sections.append((title, "\n".join(current).strip()))
            title, current = line[3:].strip(), []
        else:
            current.append(line)
    if "".join(current).strip():
        sections.append((title, "\n".join(current).strip()))

    chunks = []
    for title, text in sections:
        if len(text) <= MAX_CHARS:
            chunks.append((title, text))
            continue
        part, buf = 1, ""
        for para in text.split("\n\n"):
            if buf and len(buf) + len(para) > MAX_CHARS:
                chunks.append((f"{title} (part {part})", buf.strip()))
                part += 1
                buf = ""
            buf += para + "\n\n"
        if buf.strip():
            chunks.append((f"{title} (part {part})", buf.strip()))
    return chunks


def load_chunks(directory: Path) -> list:
    rows = []
    for path in sorted(directory.glob("*.md")):
        meta, body = parse_front_matter(path.read_text())
        for section, text in split_sections(body):
            content = f"{meta.get('title', path.stem)} — {section}\n\n{text}"  # the heading travels with the text
            chunk_id = hashlib.sha256(f"{path.name}|{section}|{content}".encode()).hexdigest()[:24]
            rows.append(
                {
                    "id": chunk_id,
                    "doc": path.name,
                    "title": meta.get("title", path.stem),
                    "section": section,
                    "audience": meta.get("audience", "customer"),
                    "product": meta.get("product"),
                    "version": meta.get("version"),
                    "effective_date": meta.get("effective_date"),
                    "content": content,
                }
            )
    return rows


DDL = """
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS index_meta (
    id              int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    embedding_model text NOT NULL,
    embedding_dim   int  NOT NULL,
    ingested_at     timestamptz NOT NULL,
    git_sha         text
);
CREATE TABLE IF NOT EXISTS chunks (
    id             text PRIMARY KEY,
    doc            text NOT NULL,
    title          text NOT NULL,
    section        text NOT NULL,
    audience       text NOT NULL,
    product        text,
    version        text,
    effective_date date,
    content        text NOT NULL,
    embedding      vector({dim}) NOT NULL,
    ingested_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS chunks_audience_idx  ON chunks (audience);
CREATE INDEX IF NOT EXISTS chunks_embedding_idx ON chunks USING hnsw (embedding vector_cosine_ops);
"""


def main() -> int:
    if not rag.KNOWLEDGE_DATABASE_URL:
        log.error("KNOWLEDGE_DATABASE_URL is not set")
        return 2
    chunks = load_chunks(KNOWLEDGE_DIR)
    if not chunks:
        log.error("no documents found in %s", KNOWLEDGE_DIR)
        return 2
    log.info("documents=%d chunks=%d", len({c["doc"] for c in chunks}), len(chunks))

    with psycopg.connect(rag.KNOWLEDGE_DATABASE_URL, connect_timeout=10) as conn:
        conn.execute(DDL.format(dim=EMBED_DIM))

        # [OPS] model-change detection: vectors from different models cannot be compared, so the index is rebuilt
        meta = conn.execute("SELECT embedding_model, embedding_dim FROM index_meta WHERE id = 1").fetchone()
        if meta and (meta[0], meta[1]) != (rag.EMBED_MODEL, EMBED_DIM):
            log.warning(
                "embedding model changed %s/%s -> %s/%s: full re-index", meta[0], meta[1], rag.EMBED_MODEL, EMBED_DIM
            )
            conn.execute("TRUNCATE chunks")

        existing = {r[0] for r in conn.execute("SELECT id FROM chunks").fetchall()}
        wanted = {c["id"]: c for c in chunks}
        new = [wanted[i] for i in wanted if i not in existing]
        stale = [i for i in existing if i not in wanted]

        for start in range(0, len(new), BATCH):  # [OPS] batched embedding calls: fewer round trips, same gateway budget
            batch = new[start : start + BATCH]
            vectors = rag.embed([c["content"] for c in batch], kind="document")
            for c, vec in zip(
                batch, vectors, strict=True
            ):  # a short embeddings reply must fail loudly, not misalign rows
                conn.execute(
                    "INSERT INTO chunks (id, doc, title, section, audience, product, version, effective_date, content, embedding) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::vector)",
                    (
                        c["id"],
                        c["doc"],
                        c["title"],
                        c["section"],
                        c["audience"],
                        c["product"],
                        c["version"],
                        c["effective_date"] or None,
                        c["content"],
                        rag.to_pgvector(vec),
                    ),
                )
        if stale:
            conn.execute("DELETE FROM chunks WHERE id = ANY(%s)", (stale,))
        conn.execute(
            "INSERT INTO index_meta (id, embedding_model, embedding_dim, ingested_at, git_sha) VALUES (1, %s, %s, now(), %s) "
            "ON CONFLICT (id) DO UPDATE SET embedding_model = EXCLUDED.embedding_model, embedding_dim = EXCLUDED.embedding_dim, "
            "ingested_at = EXCLUDED.ingested_at, git_sha = EXCLUDED.git_sha",
            (rag.EMBED_MODEL, EMBED_DIM, os.getenv("GIT_SHA")),
        )
        conn.commit()

    summary = {
        "documents": len({c["doc"] for c in chunks}),
        "chunks": len(chunks),
        "embedded": len(new),
        "unchanged": len(chunks) - len(new),
        "deleted": len(stale),
        "model": rag.EMBED_MODEL,
        "dim": EMBED_DIM,
    }
    log.info("ingest complete %s", json.dumps(summary))  # [OPS] one parseable line: the Job's log is the audit trail
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
echo "wrote ingest.py"

cat << 'EOF' > telemetry.py
"""
bank-agent / Step 15 — traces.

Metrics (app.py, agent.py) tell you THAT something is slow or failing. Traces tell you WHERE: one tree per request,
with a span per model call carrying the OpenTelemetry GenAI attributes (model, tokens, finish reason) and a span per
tool call. They are exported over OTLP/HTTP to Langfuse, which renders them next to the gateway's own records.

Tracing is optional and switched on by configuration:
  - OTEL_EXPORTER_OTLP_ENDPOINT set              -> generic OTLP collector (headers via OTEL_EXPORTER_OTLP_HEADERS)
  - else LANGFUSE_PUBLIC_KEY + LANGFUSE_SECRET_KEY -> Langfuse's OTLP endpoint, same keys the gateway uses
  - else                                          -> every span() call is a no-op; zero overhead, zero dependencies touched
"""

import base64
import os
from contextlib import contextmanager

_tracer = None


def _setup():
    global _tracer
    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"):
        exporter = OTLPSpanExporter()  # endpoint and headers from the standard OTEL_EXPORTER_OTLP_* variables
    else:
        host = os.getenv("LANGFUSE_HOST", "https://cloud.langfuse.com").rstrip("/")
        auth = base64.b64encode(
            f"{os.environ['LANGFUSE_PUBLIC_KEY']}:{os.environ['LANGFUSE_SECRET_KEY']}".encode()
        ).decode()
        exporter = OTLPSpanExporter(
            endpoint=f"{host}/api/public/otel/v1/traces", headers={"Authorization": f"Basic {auth}"}
        )
    resource = Resource.create(
        {
            "service.name": os.getenv("OTEL_SERVICE_NAME", "bank-agent"),
            "service.version": os.getenv("APP_VERSION", "unknown"),
            "deployment.environment": os.getenv("DEPLOY_ENV", "dev"),  # [OPS] filter traces per environment in Langfuse
        }
    )
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(
        BatchSpanProcessor(exporter)
    )  # [OPS] batched, background: tracing never blocks a request
    trace.set_tracer_provider(provider)
    _tracer = trace.get_tracer("bank-agent")


ENABLED = bool(
    os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or (os.getenv("LANGFUSE_PUBLIC_KEY") and os.getenv("LANGFUSE_SECRET_KEY"))
)
if ENABLED:
    _setup()


@contextmanager
def span(name: str, **attributes):
    """A child span of whatever is current, or a no-op when tracing is off. Attributes: only strings, numbers, bools."""
    if _tracer is None:
        yield None
        return
    with _tracer.start_as_current_span(name) as s:
        for key, value in attributes.items():
            if value is not None:
                s.set_attribute(key, value)
        yield s


def instrument_fastapi(app) -> None:
    """One server span per HTTP request, so the agent's spans hang off the request that caused them."""
    if ENABLED:
        from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

        FastAPIInstrumentor.instrument_app(
            app, excluded_urls="health,ready,metrics"
        )  # probes and scrapes are not traffic
EOF
echo "wrote telemetry.py"

mkdir -p "docs"
cat << 'EOF' > docs/runbook-steps-15-19.md
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
EOF
echo "wrote docs/runbook-steps-15-19.md"

echo "step16: 17 files written"