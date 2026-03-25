# GCP Secret Manager Setup for OpenClaw

**Purpose:** Securely manage GitHub PATs and other credentials without hardcoding or exposing them.

---

## Architecture

```
OpenClaw Service Account
    ↓
    ├─ (has secretmanager.secretAccessor role)
    ↓
GCP Secret Manager
    ├─ amplify_github_pat (GitHub PAT for amplify-dental-ai org)
    ├─ [other secrets as needed]
    ↓
scripts/secure-secret-retriever.sh
    ├─ Retrieves secrets at runtime (never stored on disk)
    ├─ Masks tokens in logs
    ├─ Provides secure env vars
    ↓
Git operations (clone, push, PR feedback, etc.)
```

---

## Prerequisites

1. **GCP Project** with Secret Manager enabled
2. **Service Account** running OpenClaw (typically `openclaw@project.iam.gserviceaccount.com`)
3. **Secrets** created in GCP Secret Manager (e.g., `amplify_github_pat`)

---

## Setup Steps

### 1. Create GitHub PAT Secret (One-time, done by David)

```bash
# Create the secret in GCP Secret Manager
echo "ghp_xxxxxxxxxxxx" | gcloud secrets create amplify_github_pat \
  --replication-policy="automatic" \
  --data-file=-

# Verify it was created
gcloud secrets list
```

### 2. Grant Service Account Access (One-time, done by David)

```bash
# Get the service account email (usually from OpenClaw config or GCP console)
SERVICE_ACCOUNT="openclaw@your-project.iam.gserviceaccount.com"

# Grant permission to read the secret
gcloud secrets add-iam-policy-binding amplify_github_pat \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor"

# Verify permissions
gcloud secrets get-iam-policy amplify_github_pat
```

### 3. Install gcloud CLI in OpenClaw Container (One-time, in deployment)

The `scripts/secure-secret-retriever.sh` script will auto-install gcloud if needed, but for reliability, add to your Docker image:

```dockerfile
# In your Dockerfile (or deployment config)
RUN curl https://sdk.cloud.google.com | bash
RUN gcloud components install beta
```

### 4. Set Environment Variable in Deployment (One-time, in deployment)

OpenClaw needs to know the GCP project:

```bash
# In your deployment config (.env, docker-compose, Cloud Run, etc.)
export GOOGLE_CLOUD_PROJECT="your-gcp-project-id"
```

If using Application Default Credentials (recommended):
```bash
# Cloud Run automatically sets this
# Local: gcloud auth application-default login
```

---

## Usage

### In OpenClaw Code

```python
import subprocess
import os

def get_secret(secret_name: str) -> str:
    """Retrieve secret from GCP Secret Manager."""
    result = subprocess.run(
        ["gcloud", "secrets", "versions", "access", "latest", f"--secret={secret_name}"],
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout.strip()

# Usage
github_pat = get_secret("amplify_github_pat")
```

### In Bash Scripts

```bash
source scripts/secure-secret-retriever.sh

# Retrieve a secret
token=$(get_secret "amplify_github_pat")

# Set up git credentials
setup_github_credentials "amplify_github_pat" "amplify-dental-ai"

# Use git
git clone https://${GIT_CREDENTIALS_TOKEN}@github.com/amplify-dental-ai/Amplify.git

# Clean up
cleanup_credentials
```

---

## Security Best Practices

### ✅ Do This

- **Retrieve at runtime** — Never store secrets on disk
- **Mask in logs** — Use `2>/dev/null` and avoid printing tokens
- **Clean up after** — Unset env vars when done (`cleanup_credentials`)
- **Use IAM roles** — Grant minimum necessary permissions (secretAccessor, not admin)
- **Audit secrets** — Log which operations accessed secrets (without exposing the value)
- **Rotate regularly** — Update secrets every 90 days
- **Use service accounts** — Not personal Google accounts

### ❌ Don't Do This

- ❌ Hardcode secrets in code or `.env` files
- ❌ Log or print token values
- ❌ Store tokens in git history
- ❌ Use overly permissive IAM roles (e.g., `Owner`)
- ❌ Share secrets across projects/orgs
- ❌ Forget to clean up env vars

---

## Rotation Policy

### Every 90 Days

1. **Generate new GitHub PAT** in GitHub → Settings → Developer settings
2. **Update secret** in GCP:
   ```bash
   echo "ghp_new_token..." | gcloud secrets versions add amplify_github_pat --data-file=-
   ```
3. **Verify old token works** (GCP automatically uses latest version)
4. **Revoke old token** in GitHub after 24h (in case of issues)

### If Compromised

1. **Revoke immediately** in GitHub → Settings
2. **Rotate secret** in GCP (add new version)
3. **Audit logs** to see what was accessed
4. **Notify team** if needed

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `gcloud: command not found` | Run `curl https://sdk.cloud.google.com \| bash` |
| `ERROR: (gcloud.secrets.versions.access) User does not have permission 'secretmanager.secretAccessor'` | Grant IAM role: `gcloud secrets add-iam-policy-binding <secret-name> --member=serviceAccount:<account> --role=roles/secretmanager.secretAccessor` |
| `ERROR: Could not authenticate with Google Cloud Platform` | Run `gcloud auth application-default login` (local) or ensure Cloud Run has service account |
| `Secret not found` | Check spelling, verify secret exists: `gcloud secrets list` |

---

## Audit Logging

Every secret access is logged in Google Cloud Audit Logs:

```bash
# View audit logs for secret access
gcloud logging read "resource.type=secretmanager.googleapis.com AND protoPayload.methodName=google.cloud.secretmanager.v1.SecretManagerService.AccessSecretVersion" \
  --limit 50 \
  --format json
```

---

## References

- [GCP Secret Manager Docs](https://cloud.google.com/secret-manager/docs)
- [gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference/secrets)
- [Service Account Best Practices](https://cloud.google.com/iam/docs/service-accounts-best-practices)

