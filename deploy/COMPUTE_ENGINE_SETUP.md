# Compute Engine Deployment for Althea

**Purpose:** Deploy Althea on GCP Compute Engine VM with secure secret access via Secret Manager.

---

## Architecture

```
Terraform (infra/terraform/)
    ├─ Creates Compute Engine VM
    ├─ Creates GCP Service Account
    ├─ Grants secretmanager.secretAccessor role
    └─ Injects startup.sh.tmpl as metadata startup script

VM Startup Script (startup.sh.tmpl)
    ├─ Installs Docker + Docker Compose
    ├─ Fetches secrets from Secret Manager
    ├─ Writes env files (github.env, openclaw.env, etc.)
    ├─ Clones bootstrap repo (this repo)
    └─ Runs: docker compose up -d

Docker Compose (docker-compose.yml)
    ├─ Builds Dockerfile (openclaw.Dockerfile)
    ├─ Loads env files
    ├─ Runs openclaw gateway with entrypoint.sh
    └─ entrypoint.sh retrieves AMPLIFY_GITHUB_PAT at container startup

OpenClaw
    ├─ All skills/subagents have access to env vars
    └─ Ready to handle requests
```

---

## Prerequisites

1. **GCP Project** with Compute Engine API enabled
2. **Terraform** installed locally
3. **gcloud CLI** configured for your project
4. **GitHub PAT** ready to store in Secret Manager

---

## Setup Steps

### 1. Create GCP Secret

```bash
PROJECT_ID="your-gcp-project"

# Create the secret
echo "ghp_your_github_pat..." | gcloud secrets create amplify_github_pat \
  --project=$PROJECT_ID \
  --replication-policy="automatic" \
  --data-file=-

# Verify
gcloud secrets list --project=$PROJECT_ID | grep amplify_github_pat
```

### 2. Create terraform.tfvars

Create `infra/terraform/terraform.tfvars` (or use existing):

```hcl
project_id     = "your-gcp-project"
region         = "us-central1"
zone           = "us-central1-a"
name_prefix    = "althea"
machine_type   = "n2-standard-4"

# Bootstrap repo
bootstrap_repo_url  = "https://github.com/dgrizzy/Althea.git"
bootstrap_repo_ref  = "main"
bootstrap_repo_dir  = "/opt/althea/app"
bootstrap_compose_file = "/opt/althea/app/docker-compose.yml"

# Service configuration
service_port = 18789
expose_direct_service_port = true

# GitHub setup
github_pat_secret_id       = "amplify_github_pat"  # ← Add this line
write_github_env_file      = true
github_env_file_path       = "/opt/althea/runtime/github.env"

# Telegram (if using)
telegram_bot_token_secret_id = ""  # Leave empty if not using
write_telegram_env_file      = false

# Inference
anthropic_api_key_secret_id = ""  # Leave empty or set if using
write_inference_env_file     = false

# OpenClaw Gateway
openclaw_gateway_token_secret_id = ""  # Auto-generated if empty
write_openclaw_gateway_env_file  = true
openclaw_gateway_env_file_path   = "/opt/althea/runtime/openclaw.env"
openclaw_gateway_bind            = "lan"
openclaw_primary_model           = "anthropic/claude-haiku-4-5"

# (Optional) Caddy HTTPS
enable_caddy_https = false
public_service_domain = ""
```

### 3. Initialize Terraform

```bash
cd infra/terraform
terraform init
```

### 4. Plan Terraform

```bash
terraform plan -var-file=terraform.tfvars
```

**Review the plan** — Make sure it's creating the VM, service account, and secrets correctly.

### 5. Apply Terraform

```bash
terraform apply -var-file=terraform.tfvars
```

Terraform will:
- Create VPC + Subnet
- Create VM with service account
- Grant service account Secret Manager access
- Create secrets in Secret Manager
- Start VM with startup script
- Startup script clones repo and runs docker-compose

**This takes ~5-10 minutes.**

### 6. Verify Deployment

```bash
# Get VM IP
gcloud compute instances describe althea-vm \
  --zone=us-central1-a \
  --format="get(networkInterfaces[0].accessConfigs[0].natIp)"

# SSH to VM (if you have IAP configured)
gcloud compute ssh althea-vm \
  --zone=us-central1-a \
  --tunnel-through-iap

# Check docker compose status
docker ps
docker compose logs openclaw-gateway

# Check env file
cat /opt/althea/runtime/github.env
```

### 7. Verify OpenClaw Gateway

```bash
# From your local machine (if port exposed)
curl http://<VM_IP>:18789/status

# Or through IAP tunnel
gcloud compute ssh althea-vm --zone=us-central1-a --tunnel-through-iap -- \
  curl http://127.0.0.1:18789/status
```

---

## How secrets are handled

### Startup Script

The startup script (`startup.sh.tmpl`) uses `fetch_secret_latest()` to:
1. Get VM's service account token from GCP metadata server
2. Authenticate to Secret Manager API
3. Retrieve `amplify_github_pat` secret
4. Write to `/opt/althea/runtime/github.env`

### Docker Environment

The docker-compose.yml mounts env files:
```yaml
env_file:
  - .env
  - /opt/althea/runtime/github.env
  - /opt/althea/runtime/openclaw.env
```

So `GITHUB_PAT` and `GH_TOKEN` are available inside the container.

### Container Entrypoint

The `scripts/entrypoint.sh` runs at container startup:
1. Authenticates to GCP using service account
2. Retrieves `AMPLIFY_GITHUB_PAT` from Secret Manager
3. Exports as env var
4. Passes to openclaw gateway

**Result:** All skills/subagents have access to `$AMPLIFY_GITHUB_PAT`.

---

## Updating the Deployment

### Update Code/Docker Image

```bash
# Push changes to Althea repo (main branch)
git push origin main

# SSH to VM
gcloud compute ssh althea-vm --zone=us-central1-a --tunnel-through-iap

# Pull latest and redeploy
cd /opt/althea/app
git pull origin main
docker compose build
docker compose up -d
```

### Rotate GitHub PAT

```bash
# Update secret (new version)
echo "ghp_new_token..." | gcloud secrets versions add amplify_github_pat \
  --data-file=-

# Redeploy container (pulls new secret)
gcloud compute ssh althea-vm --zone=us-central1-a --tunnel-through-iap -- \
  "cd /opt/althea/app && docker compose restart"
```

### Scale VM

```bash
# Update machine_type in terraform.tfvars
terraform apply

# Or use gcloud directly
gcloud compute instances stop althea-vm --zone=us-central1-a
gcloud compute instances set-machine-type althea-vm \
  --zone=us-central1-a \
  --machine-type=n2-standard-8
gcloud compute instances start althea-vm --zone=us-central1-a
```

---

## Troubleshooting

### "Failed to fetch secret"

Check that:
1. Secret exists: `gcloud secrets list`
2. Service account has access: `gcloud secrets get-iam-policy amplify_github_pat`
3. Secret has values: `gcloud secrets versions list amplify_github_pat`

### "docker compose: permission denied"

Check that docker group is configured:
```bash
# SSH to VM
gcloud compute ssh althea-vm --zone=us-central1-a --tunnel-through-iap

# Add user to docker group
sudo usermod -aG docker $(whoami)
newgrp docker
```

### "AMPLIFY_GITHUB_PAT not found in container"

Check env file on VM:
```bash
cat /opt/althea/runtime/github.env
```

If empty, startup script may have failed. Check:
```bash
tail -200 /var/log/syslog | grep -A5 -B5 amplify
```

### Logs

View startup script logs:
```bash
journalctl -u althea-stack.service -n 100
```

View docker compose logs:
```bash
cd /opt/althea/app
docker compose logs -f
```

---

## References

- [Terraform docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Compute Engine docs](https://cloud.google.com/compute/docs)
- [Secret Manager docs](https://cloud.google.com/secret-manager/docs)
- [IAP for SSH](https://cloud.google.com/iap/docs/using-tcp-forwarding#gcloud)

