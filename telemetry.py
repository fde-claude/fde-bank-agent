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
