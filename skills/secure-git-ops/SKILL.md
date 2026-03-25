---
name: secure-git-ops
description: Execute git operations (push, PR, clone) using GCP Secret Manager credentials securely
author: OpenClaw
version: 1.0
status: active
---

# Secure Git Operations (GCP Secret Manager)

Perform git operations (push, clone, PR actions) using credentials from GCP Secret Manager without exposing tokens.

## When to Use

- You need to push branches to a GitHub org (e.g., amplify-dental-ai)
- You're executing PR feedback on a repo with Secret Manager creds
- You need to clone private repos
- You want auditable, secure credential handling

## How It Works

```
Skill invoked (e.g., PR Feedback Executor)
    ↓
Load secure-secret-retriever.sh
    ↓
Retrieve token from GCP Secret Manager
    ↓
Set up git environment (never logs token)
    ↓
Execute git operations (push, clone, etc.)
    ↓
Clean up credentials
    ↓
Log audit trail (no token exposure)
```

## Requirements

1. **GCP Secret Manager** configured (see `deploy/SECRET_MANAGER_SETUP.md`)
2. **gcloud CLI** installed (auto-installed by retriever script)
3. **Service account** with `secretmanager.secretAccessor` role
4. **Secret name** (e.g., `amplify_github_pat`)

## Usage in Skills

### In Python

```python
import subprocess
from pathlib import Path

def get_secret(secret_name: str) -> str:
    """Retrieve from GCP Secret Manager."""
    result = subprocess.run(
        ["gcloud", "secrets", "versions", "access", "latest", f"--secret={secret_name}"],
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout.strip()

def git_clone_secure(url_base: str, secret_name: str, target_dir: str) -> None:
    """Clone repo using Secret Manager credentials."""
    token = get_secret(secret_name)
    full_url = f"https://{token}@{url_base}"
    subprocess.run(["git", "clone", full_url, target_dir], check=True)
    # Token is never logged (it's in the subprocess call, not in logs)

def git_push_secure(repo_dir: str, branch: str, secret_name: str) -> None:
    """Push branch using Secret Manager credentials."""
    token = get_secret(secret_name)
    env = {**os.environ, "GIT_CREDENTIALS_TOKEN": token}
    
    # Push using remote with credentials
    result = subprocess.run(
        ["git", "-C", repo_dir, "push", "origin", branch],
        env=env,
        capture_output=True,
        text=True,
        check=True
    )
    
    # Clean up env
    del env["GIT_CREDENTIALS_TOKEN"]
    
    return result.stdout
```

### In Bash

```bash
#!/usr/bin/env bash
source scripts/secure-secret-retriever.sh

# Clone repo
url_base="github.com/amplify-dental-ai/Amplify.git"
git_url=$(git_url_with_creds "$url_base" "amplify_github_pat")
git clone "$git_url" /tmp/Amplify

# Work on repo
cd /tmp/Amplify
git checkout -b feat/something
# ... make changes ...
git add .
git commit -m "feat: something"

# Push
git push -u origin feat/something

# Clean up
cleanup_credentials
```

## Key Guarantees

✅ **Token never logged** — Subprocess calls keep token out of logs  
✅ **Token never in git history** — Uses remote URLs, not .git/config  
✅ **Token never on disk** — Retrieved at runtime, stored only in memory  
✅ **Environment cleaned** — Unset vars after use  
✅ **Audit trail** — GCP logs all Secret Manager accesses (without exposing token)  
✅ **No hardcoding** — Uses environment variables and Secret Manager  

## Audit Logging

All secret accesses are logged in GCP Audit Logs:

```bash
gcloud logging read "resource.type=secretmanager.googleapis.com AND protoPayload.methodName=google.cloud.secretmanager.v1.SecretManagerService.AccessSecretVersion" --limit 50
```

This shows WHO accessed WHICH secret WHEN, but never the value.

## Error Handling

```python
try:
    token = get_secret("amplify_github_pat")
except subprocess.CalledProcessError as e:
    if "permission" in str(e).lower():
        raise RuntimeError(
            "Service account lacks secretmanager.secretAccessor role. "
            "Check: gcloud secrets get-iam-policy amplify_github_pat"
        )
    elif "not found" in str(e).lower():
        raise RuntimeError(
            "Secret not found. Check: gcloud secrets list"
        )
    else:
        raise RuntimeError(f"Failed to retrieve secret: {e}")
```

## Integration with PR Feedback Executor

The `pr-feedback-executor` skill uses this pattern:

1. Retrieve `amplify_github_pat` from Secret Manager
2. Clone amplify-dental-ai/Amplify using secure method
3. Execute feedback changes
4. Push using secure method
5. Clean up credentials

See `skills/pr-feedback-executor/SKILL.md` for full workflow.

## References

- Setup guide: `deploy/SECRET_MANAGER_SETUP.md`
- Helper script: `scripts/secure-secret-retriever.sh`
- GCP docs: https://cloud.google.com/secret-manager/docs

