#!/usr/bin/env bash
# Poll the ALB until /health returns 200 and reports the expected version.
# Usage: smoke-test.sh <base-url> <expected-version> [retries]
set -euo pipefail

URL="${1:?base url required}"
EXPECTED="${2:?expected version required}"
RETRIES="${3:-30}"

for i in $(seq 1 "$RETRIES"); do
  BODY=$(curl -fsS --max-time 5 "$URL/health" 2>/dev/null || true)
  if [ -n "$BODY" ] && echo "$BODY" | jq -e --arg v "$EXPECTED" '.status=="healthy" and .version==$v' >/dev/null 2>&1; then
    echo "Smoke test passed on attempt $i: $BODY"
    exit 0
  fi
  echo "Attempt $i/$RETRIES: not ready yet (${BODY:-no response})"
  sleep 10
done

echo "Smoke test FAILED for $URL/health (expected version $EXPECTED)"
exit 1
