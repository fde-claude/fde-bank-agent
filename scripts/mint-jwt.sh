#!/usr/bin/env bash
# Mint an HS256 test JWT for the APISIX jwt-auth plugin. Test tokens only; Keycloak issues real ones in Step 22.
# Usage: JWT_KEY=bank-client JWT_SECRET=<secret> ./scripts/mint-jwt.sh [ttl_seconds]
set -euo pipefail
KEY="${JWT_KEY:?set JWT_KEY (the consumer key)}"
SECRET="${JWT_SECRET:?set JWT_SECRET (the consumer secret)}"
TTL="${1:-3600}"
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
header=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
payload=$(printf '{"key":"%s","exp":%d}' "$KEY" "$(( $(date +%s) + TTL ))" | b64url)
sig=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -hmac "$SECRET" -binary | b64url)
printf '%s.%s.%s\n' "$header" "$payload" "$sig"