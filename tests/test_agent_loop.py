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
