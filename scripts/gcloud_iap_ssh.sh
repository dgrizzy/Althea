#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <instance> <project> <zone> [--command '<remote cmd>']" >&2
  exit 2
}

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ] || [ "${3:-}" = "" ]; then
  usage
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required but was not found in PATH." >&2
  exit 1
fi

INSTANCE="$1"
PROJECT="$2"
ZONE="$3"
shift 3

EXTRA_ARGS=()
if [ "${1:-}" = "--command" ]; then
  if [ "${2:-}" = "" ]; then
    usage
  fi
  EXTRA_ARGS+=(--command "$2")
fi

BASE_CMD=(
  gcloud compute ssh "${INSTANCE}"
  --project "${PROJECT}"
  --zone "${ZONE}"
  --tunnel-through-iap
)

set +e
"${BASE_CMD[@]}" "${EXTRA_ARGS[@]}"
EXIT_CODE=$?
set -e

if [ "${EXIT_CODE}" -eq 0 ]; then
  exit 0
fi

echo >&2
echo "SSH command failed with exit code ${EXIT_CODE}." >&2
echo "Running IAP/SSH troubleshoot flow..." >&2
echo >&2

set +e
"${BASE_CMD[@]}" --troubleshoot "${EXTRA_ARGS[@]}"
TROUBLESHOOT_EXIT_CODE=$?
set -e

echo >&2
echo "Troubleshoot command exit code: ${TROUBLESHOOT_EXIT_CODE}" >&2
echo "If error includes \"failed to connect to backend\" / port 22:" >&2
echo "  1) Verify VM is running and reachable in zone ${ZONE}." >&2
echo "  2) Ensure firewall allows tcp:22 from IAP range 35.235.240.0/20." >&2
echo "  3) Verify sshd is active on the VM (systemctl status ssh)." >&2
echo "  4) Install NumPy for better IAP tunnel throughput:" >&2
echo "     ./scripts/install_gcloud_numpy.sh" >&2

exit "${EXIT_CODE}"
