"""
bank-agent / Step 1 — the smallest useful Claude agent.
One model-call loop, one mock tool, no framework.

Lines tagged [OPS] are platform-team knobs: they become env vars,
ConfigMaps, Secrets or gateway settings later. Lines tagged DEV are
app-team territory (prompt, tools, business logic).
"""
import json
import os
import sys

from dotenv import load_dotenv
import anthropic

load_dotenv()  # [OPS] local only: copies .env into env vars. In K8s, Secrets/ConfigMaps do this job.

MODEL = os.getenv("MODEL_ID", "claude-haiku-5-5")  # [OPS] pinned model = image tag. Override via env, never edit code.
MAX_TURNS = 5                                      # [OPS] loop guard: hard cap on model calls per request (cost circuit breaker).

# [OPS] the SDK reads ANTHROPIC_API_KEY and ANTHROPIC_BASE_URL from the environment on its own. Pointing the app at the
#       gateway is therefore pure configuration: base URL = LiteLLM, key = a virtual key. Retries default to 2 for the
#       laptop (direct to Anthropic) and are set to 0 behind the gateway, which owns retries and fallback from Step 10 on.
client = anthropic.Anthropic(timeout=60.0, max_retries=int(os.getenv("SDK_MAX_RETRIES", "2")))


def gateway_headers(request_id: str) -> dict:
    # [OPS] Step 10: correlation and attribution for the gateway. The trace id joins edge -> app -> gateway logs into one
    #       chain; the tag makes spend queryable per workload in the admin UI. Ignored when talking to Anthropic directly.
    headers = {"x-litellm-tags": os.getenv("GATEWAY_TAG", "bank-agent")}
    if request_id:
        headers["x-litellm-trace-id"] = request_id
    return headers

SYSTEM_PROMPT = (  # DEV: the agent's standing orders. Moves out of code into a versioned file in slice 5.
    "You are a retail bank's customer-service assistant. "
    "Use tools for any account data; never guess figures. "
    "If the customer gives no account ID, ask for it."
)

# ---- DEV: one mock tool, standing in for a core-banking API call ----
MOCK_ACCOUNTS = {"ACC-1001": 25430.50, "ACC-1002": 980.00}


def get_account_balance(account_id: str) -> str:
    balance = MOCK_ACCOUNTS.get(account_id)
    if balance is None:
        return json.dumps({"error": f"account {account_id} not found"})
    return json.dumps({"account_id": account_id, "balance": balance})


TOOLS = [  # DEV: the tool's contract (JSON Schema). This is all the model ever sees of the tool.
    {
        "name": "get_account_balance",
        "description": "Return the current balance of a customer's account.",
        "input_schema": {
            "type": "object",
            "properties": {"account_id": {"type": "string", "description": "Account ID, e.g. ACC-1001"}},
            "required": ["account_id"],
        },
    }
]
TOOL_FUNCTIONS = {"get_account_balance": get_account_balance}  # DEV: route table, tool name -> Python function.


# ---- The agent loop: call model -> run requested tools -> repeat until a final answer ----
def run_agent(user_message: str, request_id: str = "") -> str:
    messages = [{"role": "user", "content": user_message}]
    for _ in range(MAX_TURNS):
        response = client.messages.create(  # one HTTPS call to the model (via the gateway from Step 10) per iteration
            model=MODEL,
            max_tokens=1024,  # [OPS] output ceiling per call (thinking tokens count too); bounds cost and latency.
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
            extra_headers=gateway_headers(request_id),
        )
        if response.stop_reason != "tool_use":  # no tool requested -> this is the final answer
            text = "".join(b.text for b in response.content if b.type == "text")
            return text or f"[no text returned, stop_reason={response.stop_reason}]"
        messages.append({"role": "assistant", "content": response.content})  # keep the model's turn (incl. tool request)
        results = [
            {"type": "tool_result", "tool_use_id": b.id, "content": TOOL_FUNCTIONS[b.name](**b.input)}
            for b in response.content
            if b.type == "tool_use"
        ]
        messages.append({"role": "user", "content": results})  # tool output goes back as the next user turn
    return "Sorry, I could not complete that request."  # [OPS] loop guard tripped


if __name__ == "__main__":
    question = " ".join(sys.argv[1:]) or "What's the balance on account ACC-1001?"
    print(run_agent(question))
