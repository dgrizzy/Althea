#!/usr/bin/env bash
# Run on the Althea VM (or via IAP SSH) to verify OpenClaw persistence wiring.
# Usage: sudo ./scripts/diagnose-openclaw-memory.sh
#        ALTHEA_APP_ROOT=/opt/althea/app sudo -E ./scripts/diagnose-openclaw-memory.sh

set -euo pipefail

ALTHEA_APP_ROOT="${ALTHEA_APP_ROOT:-/opt/althea/app}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

echo "=== OpenClaw memory / persistence diagnostics ==="
echo "ALTHEA_APP_ROOT=$ALTHEA_APP_ROOT"
echo

echo "--- Host: uptime / load ---"
uptime || true
echo

echo "--- OpenClaw home on host (resolved) ---"
if [[ -f "${ALTHEA_APP_ROOT}/.env" ]]; then
  # shellcheck disable=SC1090
  set -a
  # shellcheck source=/dev/null
  source "${ALTHEA_APP_ROOT}/.env"
  set +a
fi
OPENCLAW_HOME_DIR="${OPENCLAW_HOME_DIR:-${ALTHEA_APP_ROOT}/openclaw/home}"
if [[ "${OPENCLAW_HOME_DIR}" != /* ]]; then
  OPENCLAW_HOME_DIR="${ALTHEA_APP_ROOT}/${OPENCLAW_HOME_DIR#./}"
fi
echo "OPENCLAW_HOME_DIR (resolved)=$OPENCLAW_HOME_DIR"
if [[ -d "${OPENCLAW_HOME_DIR}" ]]; then
  ls -la "${OPENCLAW_HOME_DIR}" || true
  du -sh "${OPENCLAW_HOME_DIR}" 2>/dev/null || true
else
  echo "Directory missing (OpenClaw may create it on first run)."
fi
echo

echo "--- Persistent volume mount (if used) ---"
if mountpoint -q /mnt/openclaw-data 2>/dev/null; then
  echo "/mnt/openclaw-data is mounted"
  df -h /mnt/openclaw-data
  ls -la /mnt/openclaw-data 2>/dev/null || true
else
  echo "/mnt/openclaw-data not mounted (using boot disk path only)."
fi
echo

echo "--- Docker: compose services ---"
if [[ -d "${ALTHEA_APP_ROOT}" ]]; then
  (cd "${ALTHEA_APP_ROOT}" && docker compose -f "${COMPOSE_FILE}" ps) || true
fi
echo

echo "--- Docker: gateway container mounts ---"
GATEWAY_CID="$(docker ps -q -f name=openclaw-gateway 2>/dev/null | head -n1 || true)"
if [[ -n "${GATEWAY_CID}" ]]; then
  docker inspect "${GATEWAY_CID}" --format '{{json .Mounts}}' | python3 -m json.tool 2>/dev/null || docker inspect "${GATEWAY_CID}" --format '{{json .Mounts}}'
  echo "--- Inside container: /root/.openclaw ---"
  docker exec "${GATEWAY_CID}" ls -la /root/.openclaw/ 2>/dev/null || echo "exec failed (container not healthy?)"
  echo "--- OPENCLAW_HOME in container ---"
  docker exec "${GATEWAY_CID}" sh -c 'echo OPENCLAW_HOME="${OPENCLAW_HOME:-}"' 2>/dev/null || true
else
  echo "No running container matching name openclaw-gateway."
fi
echo

echo "--- Recent gateway logs ---"
if [[ -d "${ALTHEA_APP_ROOT}" ]]; then
  (cd "${ALTHEA_APP_ROOT}" && docker compose -f "${COMPOSE_FILE}" logs --tail=80 openclaw-gateway) 2>/dev/null || true
fi
echo

echo "--- Git repo / ignore (openclaw/home should be untracked) ---"
if [[ -d "${ALTHEA_APP_ROOT}/.git" ]]; then
  (cd "${ALTHEA_APP_ROOT}" && git status -sb && git log --oneline -3) || true
  grep -E 'openclaw' "${ALTHEA_APP_ROOT}/.gitignore" 2>/dev/null || true
fi
echo

echo "--- Optional backup artifact ---"
ls -la /opt/althea/runtime/openclaw-home-backup.tgz 2>/dev/null || echo "No /opt/althea/runtime/openclaw-home-backup.tgz"
echo
echo "Done."
