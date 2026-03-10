# Althea GCP IAM Grants – Least Privilege Summary

## Overview

This document describes all IAM grants required for Althea infrastructure and how they align with least privilege.

---

## 1. Terraform Operator (Who Runs `terraform apply`)

The identity running Terraform (via `gcloud auth application-default login` or a CI service account) needs to create and manage all resources in the project.

### Minimum Roles Required

| Role | Purpose | Why Least Privilege |
|------|---------|---------------------|
| `roles/compute.admin` | VPC, subnet, firewall, static IP, VM | Single role for all Compute resources; no broader `owner` |
| `roles/iam.serviceAccountAdmin` | Create VM service account | Can create SAs but not grant arbitrary roles |
| `roles/iam.serviceAccountUser` | Attach SA to Compute Instance | Required to set `service_account` on the VM |
| `roles/secretmanager.admin` | Create secrets + versions | Needed for `google_secret_manager_secret` and `google_secret_manager_secret_version` |
| `roles/serviceusage.serviceUsageAdmin` | Enable APIs | Required for `google_project_service` |
| `roles/resourcemanager.projectIamAdmin` | Bind IAM roles to project | Needed for `google_project_iam_member` (vm_secret_accessor, vm_log_writer) |

### Grant Command

```bash
# Replace PROJECT_ID and YOUR_EMAIL with your values
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/secretmanager.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/serviceusage.serviceUsageAdmin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/resourcemanager.projectIamAdmin"
```

**Alternative:** Use `roles/owner` for a single project/developer setup; the above is the least-privilege breakdown.

---

## 2. VM Service Account (Runtime)

The VM runs as a dedicated service account with IAM roles. The startup script and app only need:

- **Secret Manager** – read secrets at boot (Tailscale key, Telegram token, Anthropic keys)
- **Cloud Logging** – write logs from the app

### Current Grants (Already Least Privilege)

| Role | Purpose | Why Least Privilege |
|------|---------|---------------------|
| `roles/secretmanager.secretAccessor` | Read Secret Manager secrets | Read-only; cannot create, update, or delete secrets |
| `roles/logging.logWriter` | Write log entries | Append-only; cannot read or delete logs |

These roles are the minimal predefined roles for the VM’s workload.

### VM OAuth Scopes

**Current:** `cloud-platform`

Compute Engine VMs only support a [limited set of OAuth scopes](https://cloud.google.com/compute/docs/access/service-accounts#scopes). `https://www.googleapis.com/auth/secretmanager` is **not** valid for VM instances and will cause `serviceAccountScopeInvalid` errors.

Least privilege is enforced via **IAM roles** (`secretAccessor`, `logWriter`), not OAuth scopes. The `cloud-platform` scope is required for Secret Manager access from the VM.

---

## 3. APIs Enabled

| API | Purpose |
|-----|---------|
| `compute.googleapis.com` | VPC, subnet, firewall, VM, static IP |
| `secretmanager.googleapis.com` | Secret storage for credentials |
| `iamcredentials.googleapis.com` | Instance metadata / token issuance |
| `logging.googleapis.com` | Cloud Logging |

---

## 4. What the VM Does Not Need

- **Artifact Registry** – Docker pulls from Docker Hub (public)
- **Cloud Storage** – No GCS usage in startup or app
- **BigQuery, Pub/Sub, etc.** – Not used
- **IAM modification** – VM cannot change IAM bindings
- **Secret creation** – VM only reads secrets

---

## 5. Error from Terminal: Compute Engine API Propagation

The error:
```
Compute Engine API has not been used in project amplify-bots before or it is disabled
```

Occurs when `google_compute_address` is created before the Compute Engine API has finished enabling. Terraform enables the API and then immediately creates resources; propagation can take 1–2 minutes.

**Fix:** Wait 2–3 minutes after the APIs show as enabled, then run `just infra-apply` again. No IAM changes are needed.
