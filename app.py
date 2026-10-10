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
from pydantic import BaseModel, Field

from agent import MODEL, run_agent  # DEV: the Step 1 loop, reused as-is

logging.basicConfig(  # [OPS] log level via env; one line per event, parseable by any log shipper
    level=os.getenv("LOG_LEVEL", "INFO"), format="%(asctime)s %(levelname)s %(message)s"
)
log = logging.getLogger("bank-agent")

app = FastAPI(title="bank-agent", version="0.2.0")  # version shows in /docs; later it comes from the image tag


class ChatRequest(BaseModel):  # DEV: the request contract. Validation is automatic: bad input -> 422, never reaches the model
    message: str = Field(min_length=1, max_length=2000)  # [OPS] input ceiling: bounds tokens per request (cost + abuse control)


class ChatReply(BaseModel):
    reply: str
    model: str


@app.middleware("http")
async def access_log(request: Request, call_next):
    # [OPS] one structured access-log line per request: id, route, status, latency. Never the message body (PII).
    request_id = request.headers.get("x-request-id") or str(uuid.uuid4())  # honour the edge's ID, else mint one
    start = time.perf_counter()
    response = await call_next(request)
    response.headers["x-request-id"] = request_id  # echo it back so client, gateway and app logs can be joined
    log.info(
        "request_id=%s method=%s path=%s status=%s latency_ms=%.0f",
        request_id, request.method, request.url.path, response.status_code, (time.perf_counter() - start) * 1000,
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
def chat(body: ChatRequest):
    # Plain `def`, not `async def`, on purpose: the SDK call blocks, so FastAPI runs it in a worker thread
    # and the event loop stays free to answer probes. The thread pool size is this pod's concurrency ceiling.
    return ChatReply(reply=run_agent(body.message), model=MODEL)
