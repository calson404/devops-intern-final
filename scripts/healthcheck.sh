#!/usr/bin/env bash
#
# healthcheck.sh — verify a running application returns HTTP 200.
#
# Usage:
#   ./healthcheck.sh [URL]
#
# Defaults to http://localhost:8080 if no argument is given.
# Exit codes: 0 = healthy, 1 = unhealthy, 2 = misconfiguration.
#
set -euo pipefail

URL="${1:-http://localhost:8080}"
TIMEOUT=5

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required but not found in PATH" >&2
    exit 2
fi

# Capture the HTTP status code; suppress body, fail cleanly on network errors.
status="$(curl -s -o /dev/null -w '%{http_code}' --max-time "${TIMEOUT}" "${URL}" || true)"

if [ "${status}" = "200" ]; then
    echo "OK: ${URL} returned HTTP 200"
    exit 0
fi

echo "FAIL: ${URL} returned HTTP ${status:-<no response>} (expected 200)" >&2
exit 1
