# Terraform Update Notes for AMPLIFY_GITHUB_PAT

**Purpose:** Guide for updating the existing Terraform configuration to support the new secret retrieval pattern.

---

## Context

The startup script (`infra/terraform/templates/startup.sh.tmpl`) already fetches GitHub secrets and writes them to `github.env`. However, the new entrypoint.sh pattern expects `AMPLIFY_GITHUB_PAT` as an environment variable.

---

## Option 1: Simple (Recommended) - Use Existing GITHUB_PAT

**No changes needed to Terraform!**

The startup script already:
1. Fetches `amplify_github_pat` from Secret Manager
2. Writes `GITHUB_PAT`, `GH_TOKEN`, `GITHUB_TOKEN` to `/opt/althea/runtime/github.env`
3. Docker-compose loads these as env vars

So `$GITHUB_PAT` is already available in the container.

**Update docker-compose.yml** to also export as `AMPLIFY_GITHUB_PAT`:
```yaml
services:
  openclaw-gateway:
    environment:
      - AMPLIFY_GITHUB_PAT=${GITHUB_PAT}  # ← Add this line
```

Then skills can use either `$GITHUB_PAT` or `$AMPLIFY_GITHUB_PAT`.

---

## Option 2: Extend Startup Script to Export AMPLIFY_GITHUB_PAT

**Modify `infra/terraform/templates/startup.sh.tmpl`:**

After the line that writes `github_env_file_path`, add:
```bash
# Also export as AMPLIFY_GITHUB_PAT for OpenClaw skills
cat >>"${github_env_file_path}" <<EOF_AMPLIFY
AMPLIFY_GITHUB_PAT=$${GITHUB_PAT_VALUE}
EOF_AMPLIFY
```

This way, the env file contains both `GITHUB_PAT` and `AMPLIFY_GITHUB_PAT`.

**Steps:**
1. Open `infra/terraform/templates/startup.sh.tmpl`
2. Find the section where `github.env` is written
3. Add the line above to also export `AMPLIFY_GITHUB_PAT`
4. Redeploy: `terraform apply`

---

## Option 3: Add Separate amplify_github_pat Secret Retrieval

**Modify `infra/terraform/templates/startup.sh.tmpl`:**

Add a new section that specifically handles the Amplify secret:
```bash
# Retrieve Amplify GitHub PAT for OpenClaw
if [ -n "${amplify_github_pat_secret_id}" ]; then
  AMPLIFY_GITHUB_PAT="$(fetch_secret_latest "${project_id}" "${amplify_github_pat_secret_id}" || true)"
  if [ -n "$${AMPLIFY_GITHUB_PAT}" ]; then
    AMPLIFY_ENV_DIR="$(dirname "${amplify_github_pat_env_file_path}")"
    install -d -m 0750 "$${AMPLIFY_ENV_DIR}"
    umask 177
    cat >"${amplify_github_pat_env_file_path}" <<EOF_AMP
AMPLIFY_GITHUB_PAT=$${AMPLIFY_GITHUB_PAT}
EOF_AMP
    chmod 0600 "${amplify_github_pat_env_file_path}"
  else
    echo "Amplify GitHub PAT secret '${amplify_github_pat_secret_id}' unavailable."
  fi
fi
```

Then add to `docker-compose.yml`:
```yaml
env_file:
  - .env
  - ${OPENCLAW_GATEWAY_ENV_FILE:-/opt/althea/runtime/openclaw.env}
  - ${AMPLIFY_GITHUB_PAT_ENV_FILE:-/opt/althea/runtime/amplify.env}  # ← Add
```

And to `infra/terraform/main.tf` (in the templatefile call):
```hcl
amplify_github_pat_secret_id = var.amplify_github_pat_secret_id
amplify_github_pat_env_file_path = var.amplify_github_pat_env_file_path
```

Then add to `infra/terraform/variables.tf`:
```hcl
variable "amplify_github_pat_secret_id" {
  type = string
  default = "amplify_github_pat"
}

variable "amplify_github_pat_env_file_path" {
  type = string
  default = "/opt/althea/runtime/amplify.env"
}
```

---

## Recommendation

**Use Option 1** — it's the simplest. The GitHub PAT is already being fetched and available. Just alias it as `AMPLIFY_GITHUB_PAT` in docker-compose.yml.

**Changes needed:**
1. Update `docker-compose.yml` to export `AMPLIFY_GITHUB_PAT=${GITHUB_PAT}`
2. Redeploy container

That's it!

---

## Verification

After deployment, verify the env var is available:

```bash
# SSH to VM
gcloud compute ssh althea-vm --zone=us-central1-a --tunnel-through-iap

# Check docker env
docker exec althea-openclaw-gateway printenv | grep AMPLIFY_GITHUB_PAT

# Should output:
# AMPLIFY_GITHUB_PAT=ghp_xxxxx...
```

