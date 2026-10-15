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

REDIS_URL = os.getenv("REDIS_URL", "")                    # [OPS] empty = memory disabled (CLI, tests). redis://host:6379/1 in Compose and K8s
MEMORY_TURNS = int(os.getenv("MEMORY_TURNS", "10"))        # [OPS] sliding window: last N user/assistant pairs. Bounds tokens per request.
MEMORY_TTL = int(os.getenv("MEMORY_TTL_SECONDS", "1800"))  # [OPS] sessions expire after 30 min of silence. Nothing lingers forever.

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
    turns = turns[-2 * MEMORY_TURNS:]  # keep whole pairs; the oldest fall off the window
    try:
        _client.set(_key(session_id), json.dumps(turns), ex=MEMORY_TTL)
    except redis.RedisError as exc:
        log.warning("memory not saved: %s", type(exc).__name__)
