#!/usr/bin/env bash
# Every model ID behind a gateway alias must still be offered by the provider. Retired IDs fail with 404 at request time,
# which is how a bank finds out at 9am on a Monday. This asks the provider's model list instead, every night.
# Usage: ANTHROPIC_API_KEY=... ./scripts/check-models.sh [config.yaml]
set -euo pipefail
CONFIG="${1:-deploy/chart/litellm/files/config.yaml}"
: "${ANTHROPIC_API_KEY:?set ANTHROPIC_API_KEY (the CI key is fine)}"
available=$(curl -sf https://api.anthropic.com/v1/models?limit=1000 -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" \
            | python3 -c "import sys,json; print('\n'.join(m['id'] for m in json.load(sys.stdin)['data']))")
bad=0
for id in $(grep -oE "model:\s*anthropic/[a-z0-9.-]+" "$CONFIG" | sed 's#.*anthropic/##' | sort -u); do
  if grep -qx "$id" <<< "$available"; then echo "ok:       $id"; else echo "MISSING:  $id (retired or renamed)"; bad=1; fi
done
exit $bad
