#!/usr/bin/env bash
# Every `uses:` in every workflow must reference a full 40-character commit SHA. Tags can be repointed; SHAs cannot.
# Runs in the nightly drift job and locally:  ./scripts/check-action-pins.sh
set -euo pipefail
bad=0
while IFS= read -r line; do
  ref="${line#*uses: }"; ref="${ref%% *}"; ref="${ref//\"/}"
  case "$ref" in
    ./*|docker://*) continue ;;                       # local composite actions and docker images are not tag-pinned refs
  esac
  if ! [[ "$ref" =~ @[0-9a-f]{40}$ ]]; then
    echo "UNPINNED: $ref"; bad=1
  fi
done < <(grep -rhoE "uses:\s*[^ ]+" .github/workflows/)
[ "$bad" = 0 ] && echo "all actions pinned to commit SHAs"
exit $bad
