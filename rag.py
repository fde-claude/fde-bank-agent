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
