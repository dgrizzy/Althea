# GCP Secret Manager Setup for OpenClaw

**Purpose:** Securely manage GitHub PATs and other credentials without hardcoding or exposing them.

---

## Architecture

```
OpenClaw Deployment
    ├─ Dockerfile
    │   ├─ Installs gcloud CLI
    │   └─ Sets up entrypoint.sh
    │
    ├─ scripts/entrypoint.sh (runs at container startup)
    │   ├─ Authenticates to GCP using service account
    │   ├─ Retrieves secrets from Secret Manager (once)
    │   └─ Exports as env vars (AMPLIFY_GITHUB_PAT, etc.)
    │
    ├─ OpenClaw Service Account
    │   └─ (has secretmanager.secretAccessor role)
    │
    ├─ GCP Secret Manager
    │   ├─ amplify_github_pat (GitHub PAT for amplify-dental-ai org)
    │   └─ [other secrets as needed]
    │
    └─ OpenClaw Runtime
        ├─ All skills/subagents have access to env vars
        ├─ Skills use AMPLIFY_GITHUB_PAT directly (no API calls)
        └─ Git operations (clone, push, PR feedback, etc.)
```

**Key benefit:** Secrets retrieved once at startup. Skills just use environment variables. No direct secret API calls from individual skills.

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

### 3. Dockerfile Already Configured

The `Dockerfile` in this repo already:
- ✅ Installs gcloud CLI at build time
- ✅ Sets up `scripts/entrypoint.sh` as the container entrypoint
- ✅ Entrypoint retrieves secrets at startup and exports as env vars

No additional Docker changes needed!

### 4. Set Environment Variable in Deployment

OpenClaw needs to know the GCP project. Set in your deployment config:

```bash
# In your deployment config (.env, docker-compose, Cloud Run, etc.)
export GOOGLE_CLOUD_PROJECT="your-gcp-project-id"
```

**For Cloud Run:**
```bash
gcloud run deploy openclaw \
  --set-env-vars=GOOGLE_CLOUD_PROJECT=your-gcp-project-id \
  --service-account=openclaw@your-project.iam.gserviceaccount.com \
  ...
```

**For Docker Compose:**
```yaml
services:
  openclaw:
    image: openclaw:latest
    environment:
      - GOOGLE_CLOUD_PROJECT=your-gcp-project-id
    # Uses service account credentials from GOOGLE_APPLICATION_CREDENTIALS
```

**For local development:**
```bash
export GOOGLE_CLOUD_PROJECT="your-gcp-project-id"
gcloud auth application-default login
docker build -t openclaw .
docker run -e GOOGLE_CLOUD_PROJECT openclaw
```

---

## Usage

### In Skills / Subagents (Recommended)

**Secrets are already available as environment variables at runtime.**

```python
# Python
import os

github_pat = os.environ.get("AMPLIFY_GITHUB_PAT")
if not github_pat:
    raise RuntimeError("AMPLIFY_GITHUB_PAT not found. Secret not retrieved at startup.")

# Use it directly
git_url = f"https://{github_pat}@github.com/amplify-dental-ai/Amplify.git"
subprocess.run(["git", "clone", git_url, "/tmp/Amplify"], check=True)
```

```bash
# Bash
if [ -z "$AMPLIFY_GITHUB_PAT" ]; then
    echo "ERROR: AMPLIFY_GITHUB_PAT not found. Secret not retrieved at startup."
    exit 1
fi

# Use directly
git clone "https://${AMPLIFY_GITHUB_PAT}@github.com/amplify-dental-ai/Amplify.git" /tmp/Amplify
```

### For One-Off Secret Retrieval (Advanced)

If you need to retrieve a secret at runtime (not recommended for performance):

```bash
# Bash - source the helper script
source scripts/secure-secret-retriever.sh
token=$(get_secret "some_secret")
```

```python
# Python - use subprocess
import subprocess

result = subprocess.run(
    ["gcloud", "secrets", "versions", "access", "latest", "--secret=some_secret"],
    capture_output=True,
    text=True,
    check=True
)
token = result.stdout.strip()
```

**Note:** This is not recommended. Prefer using env vars loaded at startup.

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

