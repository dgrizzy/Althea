# Althea Terraform (GCP)

This stack provisions a VM-centric OpenClaw runtime host:
- VPC + subnet
- Firewall rules (SSH + optional service ingress)
- Static external IP
- VM for runtime/bootstrap
- Service account + IAM bindings
- Secret Manager secret container for Tailscale auth key
- Secret Manager secret container for GitHub App private key
- Secret Manager secret container for OpenClaw gateway token
- Optional Tailscale install + auto-join on VM bootstrap
- Optional Telegram token/inference key/GitHub App key/Claude Code key env-file materialization from Secret Manager
- Optional Caddy HTTPS reverse proxy for the service endpoint

## Prereqs

- Terraform >= 1.6
- Authenticated GCP credentials (`gcloud auth application-default login`)
- A GCP project with billing enabled

## Files

- `main.tf`: infrastructure resources
- `variables.tf`: input contract
- `outputs.tf`: endpoint and IDs
- `terraform.tfvars.example`: starter values
- `templates/startup.sh.tmpl`: VM bootstrap script

## Usage

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

After apply:
- Use output `service_url` to get the access target.
- Ensure `bootstrap_repo_url` points at your deployment repo so startup automation brings up the stack.
- Lock down `admin_source_ranges` and `service_source_ranges` from `0.0.0.0/0` in production.
- Keep `enable_iap_ssh = true` so IAP SSH stays available even when `admin_source_ranges` is tightly scoped.
- Bootstrap will copy `.env.example` to `.env` when missing before starting compose.

Tailscale-only mode:

- `expose_direct_service_port = false`
- `enable_caddy_https = false`
- Access service through tailnet host/IP on `service_port` (default `18789`) or an SSH tunnel.

## HTTPS reverse proxy pattern (Caddy)

Set these in `terraform.tfvars`:

- `enable_caddy_https = true`
- `public_service_domain = "bot.yourdomain.com"`
- `caddy_acme_email = "ops@yourdomain.com"` (optional, recommended)
- `caddy_acme_ca = "https://acme-v02.api.letsencrypt.org/directory"`
- `enable_persistent_caddy_storage = true`
- `caddy_data_disk_size_gb = 10`
- `caddy_data_disk_type = "pd-balanced"`
- `expose_direct_service_port = false` (recommended after cutover)

Bootstrap behavior is idempotent:
- Caddy config is only reloaded when it changes.
- If config is unchanged, bootstrap does not force a caddy restart.
- Caddy is pinned to a single ACME issuer URL.
- Cert state is persisted at `/var/lib/caddy`; do not wipe this path.

## Tailscale pattern

Set these in `terraform.tfvars`:

- `enable_tailscale = true`
- `tailscale_hostname = "amplify-bots-vm"`
- `tailscale_advertise_tags = ["tag:amplify-bots"]`
- `tailscale_ssh = true`

Auth key handling:

- Secret container `${name_prefix}-tailscale-auth-key` is created automatically.
- Create a Secret Manager version with your Tailscale auth key.
- Startup script reads that secret and runs `tailscale up`.
- You can override secret name with `tailscale_auth_key_secret_id`.

## Runtime secret env-file pattern

On VM startup, Terraform can materialize env files for your runtime:

- Telegram bot token: `/opt/althea/runtime/telegram.env`
- OpenClaw inference key + model: `/opt/althea/runtime/inference.env`
- OpenClaw gateway token/bind/port: `/opt/althea/runtime/openclaw.env`
- GitHub credentials for `gh` (PAT and/or App): `/opt/althea/runtime/github.env` + optional `/opt/althea/runtime/github-app.pem`
- Claude Code key + model: `/opt/althea/runtime/claude-code.env`

These values are fetched from Secret Manager IDs configured in `terraform.tfvars`.

For PAT-first GitHub auth, set:

- `github_pat_secret_id = "github_pat"`

For Claude Code execution path, ensure:

- `claude_code_anthropic_api_key_secret_id` points to your Claude Code key secret
- `claude_code_model` and `claude_code_subagent_model` are set to your desired model aliases

## Notes

- Initial secret versions are optional and disabled by default.
- The startup script installs Docker and requires `bootstrap_repo_url` to clone and run compose.
