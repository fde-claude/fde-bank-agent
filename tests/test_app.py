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
