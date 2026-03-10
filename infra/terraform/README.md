# Althea Terraform (GCP)

This stack provisions first-pass infrastructure for Althea:
- VPC + subnet
- Firewall rules (SSH + webhook ingress)
- Static external IP
- VM for OpenClaw + Althea runtime
- Service account + IAM bindings
- Secret Manager secrets for core credentials
- Optional Tailscale install + auto-join on VM bootstrap
- Optional Telegram bot token env-file materialization from Secret Manager
- Optional Anthropic inference key env-file materialization from Secret Manager
- Optional Claude Code Anthropic key env-file materialization from Secret Manager
- Optional Caddy HTTPS reverse proxy provisioning for GitHub webhook endpoint

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
- Use output `webhook_url` in GitHub webhook settings.
- Ensure `bootstrap_repo_url` points at your deployment repo so startup automation brings up the stack.
- Lock down `webhook_source_ranges` from `0.0.0.0/0` to known CIDRs.

## HTTPS reverse proxy pattern (Caddy)

Set these in `terraform.tfvars`:

- `enable_caddy_https = true`
- `public_webhook_domain = "bots.yourdomain.com"`
- `caddy_acme_email = "ops@yourdomain.com"` (optional, recommended)
- `expose_direct_webhook_port = false` (recommended after cutover)

When enabled, startup script installs Caddy, configures TLS, and proxies:

- `https://<public_webhook_domain>/webhooks/github` -> `127.0.0.1:<webhook_port>`

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

## Telegram bot secret pattern

Defaults are prewired for your secret:

- `telegram_bot_token_secret_id = "telegram-reasonable-dev-bot"`
- `write_telegram_env_file = true`
- `telegram_env_file_path = "/opt/althea/runtime/telegram.env"`

On VM startup, the script fetches that secret and writes `TELEGRAM_BOT_TOKEN` to the env file with `0600` permissions.

## Anthropic inference secret pattern

Defaults are prewired for your secret:

- `anthropic_api_key_secret_id = "amplify-dev-bot-anthropic-api-openclaw"`
- `write_inference_env_file = true`
- `inference_env_file_path = "/opt/althea/runtime/inference.env"`
- `openclaw_primary_model = "haiku"`

On VM startup, the script fetches that secret and writes:

- `ANTHROPIC_API_KEY`
- `OPENCLAW_PRIMARY_MODEL`

to the env file with `0600` permissions.

## Claude Code Anthropic secret pattern

Defaults are prewired for your secret:

- `claude_code_anthropic_api_key_secret_id = "amplify-dev-bot-anthropic-api-claude-code"`
- `write_claude_code_env_file = true`
- `claude_code_env_file_path = "/opt/althea/runtime/claude-code.env"`
- `claude_code_model = "haiku"`

On VM startup, the script fetches that secret and writes:

- `ANTHROPIC_API_KEY`
- `CLAUDE_CODE_MODEL`

to the env file with `0600` permissions.

## Notes

- For production, use HTTPS termination in front of webhook ingress.
- Initial secret versions are optional and disabled by default.
- The startup script installs Docker and requires `bootstrap_repo_url` to clone and run compose.
