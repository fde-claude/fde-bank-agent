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
