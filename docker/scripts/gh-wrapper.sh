#!/usr/bin/env bash
set -euo pipefail

if [ -x /usr/local/bin/gh-app-token.js ] && [ -n "${GITHUB_APP_ID:-}" ] && [ -n "${GITHUB_INSTALLATION_ID:-}" ]; then
  if GH_TOKEN_VALUE="$(/usr/local/bin/gh-app-token.js 2>/dev/null)"; then
    export GH_TOKEN="${GH_TOKEN_VALUE}"
  fi
fi

exec /usr/bin/gh "$@"
