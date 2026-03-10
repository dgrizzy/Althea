#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${1:-app-openclaw-gateway-1}"
TARGET_REPO="${2:-}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -Fxq "${CONTAINER_NAME}"; then
  echo "container not running: ${CONTAINER_NAME}" >&2
  exit 1
fi

echo "[1/5] Checking GitHub auth material inside ${CONTAINER_NAME}"
AUTH_MODE="$(
  docker exec "${CONTAINER_NAME}" sh -lc '
    if [ -n "${GITHUB_PAT:-}" ] || [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
      echo "pat"
      exit 0
    fi

    if [ -n "${GITHUB_APP_ID:-}" ] && [ -n "${GITHUB_INSTALLATION_ID:-}" ] && [ -n "${GITHUB_APP_PRIVATE_KEY_PATH:-}" ] && [ -s "${GITHUB_APP_PRIVATE_KEY_PATH}" ]; then
      echo "app"
      exit 0
    fi

    echo "none"
  '
)"

if [ "${AUTH_MODE}" = "none" ]; then
  echo "No GitHub auth configured (neither PAT nor App)." >&2
  exit 1
fi

echo "Auth mode detected: ${AUTH_MODE}"

echo "[2/5] Verifying gh wrapper is available"
docker exec "${CONTAINER_NAME}" sh -lc 'gh --version | head -n1'

if [ "${AUTH_MODE}" = "app" ]; then
  echo "[3/5] Minting installation token"
  docker exec "${CONTAINER_NAME}" /usr/local/bin/gh-app-token.js --json
else
  echo "[3/5] PAT mode selected; token minting step skipped"
fi

echo "[4/5] Calling GitHub API with configured auth"
docker exec "${CONTAINER_NAME}" sh -lc 'gh api /rate_limit --jq ".rate.remaining"'

if [ -n "${TARGET_REPO}" ]; then
  echo "[5/5] Verifying repo visibility: ${TARGET_REPO}"
  docker exec "${CONTAINER_NAME}" sh -lc "gh api /repos/${TARGET_REPO} --jq .full_name"
else
  echo "[5/5] Repo visibility check skipped (no repo arg provided)"
fi

echo "GitHub runtime validation passed."
