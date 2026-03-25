#!/usr/bin/env bash
# Create a timestamped tar.gz of the OpenClaw home directory (memory/sessions/workspace).
# Intended for systemd timer on the VM; can be run manually.
#
# Environment:
#   ALTHEA_APP_ROOT      - repo root (default /opt/althea/app)
#   OPENCLAW_BACKUP_ROOT - directory for archives (default /mnt/openclaw-data/backups, else /opt/althea/runtime)
#   BACKUP_RETAIN_COUNT  - number of newest archives to keep (default 7)

set -euo pipefail

ALTHEA_APP_ROOT="${ALTHEA_APP_ROOT:-/opt/althea/app}"
BACKUP_RETAIN_COUNT="${BACKUP_RETAIN_COUNT:-7}"

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

if [[ -z "${OPENCLAW_BACKUP_ROOT:-}" ]]; then
  if [[ -d /mnt/openclaw-data/backups ]]; then
    OPENCLAW_BACKUP_ROOT="/mnt/openclaw-data/backups"
  else
    OPENCLAW_BACKUP_ROOT="/opt/althea/runtime"
  fi
fi

if [[ ! -d "${OPENCLAW_HOME_DIR}" ]]; then
  echo "OpenClaw home not found (skip): ${OPENCLAW_HOME_DIR}" >&2
  exit 0
fi

install -d -m 0750 "${OPENCLAW_BACKUP_ROOT}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="${OPENCLAW_BACKUP_ROOT}/openclaw-home-${TS}.tgz"

# Archive directory contents; strip leading path for safer restore.
tar -czf "${ARCHIVE}" -C "$(dirname "${OPENCLAW_HOME_DIR}")" "$(basename "${OPENCLAW_HOME_DIR}")"
chmod 0640 "${ARCHIVE}" || true
echo "Wrote ${ARCHIVE}"

# Prune old backups (same prefix)
mapfile -t ALL < <(ls -1t "${OPENCLAW_BACKUP_ROOT}"/openclaw-home-*.tgz 2>/dev/null || true)
if ((${#ALL[@]} > BACKUP_RETAIN_COUNT)); then
  for ((i = BACKUP_RETAIN_COUNT; i < ${#ALL[@]}; i++)); do
    rm -f "${ALL[$i]}"
    echo "Removed old backup: ${ALL[$i]}"
  done
fi
