# Step 9 — LiteLLM admin UI lab (OPS)

Purpose: operate the south AI gateway from its UI. Keys, teams, budgets and spend are *data* and belong in the UI;
models, aliases and fallbacks are *configuration* and stay in `deploy/litellm/config.yaml`.

Prerequisites: `.env` has the five new values (see `.env.example`), `docker compose up -d` is healthy:

```bash
docker compose ps                         # agent, postgres, redis, litellm all (healthy)
docker compose logs litellm | tail -20    # look for: "Proxy initialized with Config, Set models: bank-primary, bank-fallback"
```

UI: http://localhost:4000/ui → sign in with `UI_USERNAME` / `UI_PASSWORD` from `.env`.
Keep a terminal ready; `$MASTER` is `LITELLM_MASTER_KEY` from `.env`.

---

## Task 1 — Read the configuration the UI did not create (3 min)

Models page. Expected: `bank-primary` and `bank-fallback`, provider Anthropic, input/output cost per token filled in
from LiteLLM's price table (Haiku 5.5: $0.10 / $0.50 per million tokens, Opus 5.5: $4 / $20).
Everything here came from `config.yaml`. Try editing a model: with `store_model_in_db: false` the file wins on restart.

## Task 2 — Team and virtual key (5 min)

Teams → create `bank-agent-dev`: max budget **5 USD**, budget duration **30d**, models `bank-primary`, `bank-fallback`.

Virtual Keys → create key: team `bank-agent-dev`, alias `bank-agent-dev-key`, models `bank-primary`,
max budget **2 USD / 30d**, RPM **60**. Copy the key now; it is shown once. Store it in the terminal: `export VKEY=sk-...`

Lesson: the application will hold this key (Step 10), never the provider key. Revoking it costs nothing and breaks nothing else.

## Task 3 — First request through the gateway, two protocols (3 min)

```bash
# OpenAI-compatible endpoint
curl -s http://localhost:4000/v1/chat/completions -H "Authorization: Bearer $VKEY" -H 'content-type: application/json' \
  -d '{"model":"bank-primary","messages":[{"role":"user","content":"Say hello in five words."}]}' | head -c 400; echo
# Anthropic-native endpoint: the one the Anthropic SDK in agent.py will use after Step 10
curl -s http://localhost:4000/v1/messages -H "x-api-key: $VKEY" -H "anthropic-version: 2023-06-01" -H 'content-type: application/json' \
  -d '{"model":"bank-primary","max_tokens":64,"messages":[{"role":"user","content":"Say hello in five words."}]}' | head -c 400; echo
```

Logs page: both requests, with model, tokens, cost, latency and the key alias. Open one: no prompt text is stored
(`store_prompts_in_spend_logs: false`).

## Task 4 — Fallback drill, no outage required (3 min)

```bash
curl -s http://localhost:4000/v1/chat/completions -H "Authorization: Bearer $VKEY" -H 'content-type: application/json' \
  -d '{"model":"bank-primary","mock_testing_fallbacks":true,"messages":[{"role":"user","content":"Which model are you?"}]}' | head -c 300; echo
```

Logs page: the request shows `bank-fallback` (Opus) as the model that answered, and Opus pricing on the cost column.
Lesson: the app asked for `bank-primary` and got an answer anyway. The routing decision is invisible to the caller.

## Task 5 — Budget enforcement (4 min)

Create a second key: alias `tiny-budget`, max budget **0.001 USD**, model `bank-primary`. Send two or three requests with it.
Expected: the first succeeds, a following one returns **429** with a budget-exceeded message. Usage page → the key shows red.
Lesson: a leaked or runaway key can cost at most its budget. This is the control that makes per-agent keys worth the effort.

## Task 6 — Rate limit enforcement (2 min)

Edit the `tiny-budget` key (or create another): RPM **2**. Send three requests inside a minute → the third is **429**.
Compare with APISIX's limit from Step 7: north limits protect the app per client; south limits protect the model budget per workload.

## Task 7 — Revoke and rotate (2 min)

Virtual Keys → delete `tiny-budget`. Its next request → **401**. Then regenerate `bank-agent-dev-key`: the old value stops working,
the new one carries the same team, budget and limits. Rotation is a UI action with zero deploys.

## Task 8 — Prompt caching, the cheaper kind of caching (optional, 4 min)

```bash
BIG=$(python3 -c "print('Bank policy manual. ' * 400)")
for i in 1 2; do curl -s http://localhost:4000/v1/messages -H "x-api-key: $VKEY" -H "anthropic-version: 2023-06-01" -H 'content-type: application/json' \
  -d "{\"model\":\"bank-primary\",\"max_tokens\":32,\"system\":[{\"type\":\"text\",\"text\":\"$BIG\",\"cache_control\":{\"type\":\"ephemeral\"}}],\"messages\":[{\"role\":\"user\",\"content\":\"Reply OK\"}]}" \
  | python3 -c "import sys,json; u=json.load(sys.stdin)['usage']; print({k:v for k,v in u.items() if 'cache' in k or 'input' in k})"; done
```

Expected: the first call shows `cache_creation_input_tokens`, the second `cache_read_input_tokens` of the same size.
Logs page: the second request is cheaper. Step 12 turns this on for the agent's system prompt.

---

## What to take away

- UI for: keys, teams, budgets, rate limits, spend, logs, rotating and revoking. These are operational data and change daily.
- Git for: which models exist, what the aliases mean, how fallback and retries behave, what is logged and for how long.
- The gateway database is now Tier-0: Step 11 covers its backup and the gateway's own HA.
- Two different "caches": response caching is off because the traffic is personalised; prompt caching is on per request and is safe.
