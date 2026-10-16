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
