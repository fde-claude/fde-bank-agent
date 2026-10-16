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
