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
 
client = anthropic.Anthropic(timeout=60.0, max_retries=2)  # [OPS] reads ANTHROPIC_API_KEY; per-call timeout; auto-retry on 429/5xx.
 
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
def run_agent(user_message: str) -> str:
    messages = [{"role": "user", "content": user_message}]
    for _ in range(MAX_TURNS):
        response = client.messages.create(  # one HTTPS call to the model per iteration
            model=MODEL,
            max_tokens=1024,  # [OPS] output ceiling per call (thinking tokens count too); bounds cost and latency.
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
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