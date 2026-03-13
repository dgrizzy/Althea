#!/usr/bin/env bash
set -euo pipefail

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required but was not found in PATH." >&2
  exit 1
fi

GCLOUD_PYTHON="$(gcloud info --format='value(basic.python_location)')"
if [ -z "${GCLOUD_PYTHON}" ]; then
  echo "Unable to determine gcloud python location." >&2
  exit 1
fi

echo "Installing/Upgrading NumPy for gcloud tunnel performance..."
"${GCLOUD_PYTHON}" -m pip install --upgrade numpy

if [ "${CLOUDSDK_PYTHON_SITEPACKAGES:-}" != "1" ]; then
  echo
  echo "Recommendation: set CLOUDSDK_PYTHON_SITEPACKAGES=1 so gcloud can use site packages."
  echo "For bash:  echo 'export CLOUDSDK_PYTHON_SITEPACKAGES=1' >> ~/.bashrc"
fi

echo "Done. Re-run your gcloud SSH or IAP tunnel command."
