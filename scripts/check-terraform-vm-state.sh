#!/usr/bin/env bash
# Run locally from the repo root to inspect Terraform state for VM replacement signals.
# Requires: terraform initialized in infra/terraform, and state available.
#
# Usage:
#   ./scripts/check-terraform-vm-state.sh
#   TF_DIR=infra/terraform ./scripts/check-terraform-vm-state.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-${ROOT}/infra/terraform}"

if [[ ! -d "${TF_DIR}" ]]; then
  echo "Terraform directory not found: ${TF_DIR}" >&2
  exit 1
fi

cd "${TF_DIR}"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform not found in PATH" >&2
  exit 1
fi

echo "=== Terraform VM / disk resources (state) ==="
terraform state list 2>/dev/null | grep -E 'google_compute_instance|google_compute_disk' || {
  echo "(no matching resources or state not initialized)"
}
echo

echo "=== google_compute_instance.this (summary) ==="
if terraform state show 'google_compute_instance.this' >/tmp/tf-vm-show.txt 2>/dev/null; then
  grep -E '^(id |name |machine_type |zone |creation_timestamp )' /tmp/tf-vm-show.txt || cat /tmp/tf-vm-show.txt
else
  echo "Resource google_compute_instance.this not in state."
fi
echo

echo "=== Attached / data disks in state ==="
terraform state list 2>/dev/null | grep 'google_compute_disk' || true
for res in $(terraform state list 2>/dev/null | grep '^google_compute_disk\.'); do
  echo "--- ${res} ---"
  terraform state show "${res}" 2>/dev/null | grep -E '^(id |name |size |type )' || true
done
echo

echo "=== Hint ==="
echo "If the VM was recreated (terraform apply replace), the boot disk is new and any"
echo "OpenClaw data that lived only under /opt/althea/app/openclaw/home on the boot disk is gone."
echo "Use enable_persistent_openclaw_storage (see infra/terraform) so home survives VM replacement."
echo
echo "To see whether the next apply would replace the instance:"
echo "  cd ${TF_DIR} && terraform plan -var-file=terraform.tfvars -no-color | grep -E 'must be replaced|forces replacement' || true"
