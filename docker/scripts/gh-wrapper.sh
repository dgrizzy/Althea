#!/usr/bin/env bash
set -euo pipefail

# Prefer explicit token values if provided (PAT/runtime token).
if [ -z "${GH_TOKEN:-}" ]; then
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    export GH_TOKEN="${GITHUB_TOKEN}"
  elif [ -n "${GITHUB_PAT:-}" ]; then
    export GH_TOKEN="${GITHUB_PAT}"
  fi
fi

# Fallback to GitHub App token minting when PAT/token is not present.
if [ -z "${GH_TOKEN:-}" ] && [ -x /usr/local/bin/gh-app-token.js ] && [ -n "${GITHUB_APP_ID:-}" ] && [ -n "${GITHUB_INSTALLATION_ID:-}" ]; then
  if GH_TOKEN_VALUE="$(/usr/local/bin/gh-app-token.js 2>/dev/null)"; then
    export GH_TOKEN="${GH_TOKEN_VALUE}"
  fi
fi

if [ -n "${GH_TOKEN:-}" ] && [ -z "${GITHUB_TOKEN:-}" ]; then
  export GITHUB_TOKEN="${GH_TOKEN}"
fi

exec /usr/bin/gh "$@"
