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

echo "[1/5] Checking GitHub App env vars inside ${CONTAINER_NAME}"
docker exec "${CONTAINER_NAME}" sh -lc '
  for key in GITHUB_APP_ID GITHUB_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY_PATH; do
    if [ -z "${!key:-}" ]; then
      echo "missing env var: ${key}" >&2
      exit 1
    fi
  done
  if [ ! -s "${GITHUB_APP_PRIVATE_KEY_PATH}" ]; then
    echo "missing or empty private key file: ${GITHUB_APP_PRIVATE_KEY_PATH}" >&2
    exit 1
  fi
'

echo "[2/5] Minting installation token"
docker exec "${CONTAINER_NAME}" /usr/local/bin/gh-app-token.js --json

echo "[3/5] Verifying gh wrapper is available"
docker exec "${CONTAINER_NAME}" sh -lc 'gh --version | head -n1'

echo "[4/5] Calling GitHub API with app installation token"
docker exec "${CONTAINER_NAME}" sh -lc 'gh api /rate_limit --jq ".rate.remaining"'

if [ -n "${TARGET_REPO}" ]; then
  echo "[5/5] Verifying repo visibility: ${TARGET_REPO}"
  docker exec "${CONTAINER_NAME}" sh -lc "gh api /repos/${TARGET_REPO} --jq .full_name"
else
  echo "[5/5] Repo visibility check skipped (no repo arg provided)"
fi

echo "GitHub App runtime validation passed."
