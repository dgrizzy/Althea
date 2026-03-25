# Infra

Althea infrastructure is provisioned via Terraform under `infra/terraform`.

## What it creates

- VPC and subnet
- Firewall rules for SSH and optional HTTPS ingress
- Static IP for VM endpoint
- Compute Engine VM for runtime
- VM service account and IAM bindings
- Secret Manager secret containers

## Standard flow

1. Copy `infra/terraform/terraform.tfvars.example` to `infra/terraform/terraform.tfvars`.
2. Set `project_id`, `admin_source_ranges`, and `bootstrap_repo_url`.
   For Tailscale-only mode, set `expose_direct_service_port=false` and `enable_caddy_https=false`.
   Keep `service_port=18789` for OpenClaw gateway.
   If using HTTPS endpoint on the VM, set `enable_caddy_https=true` and `public_service_domain`.
3. Run:
   - `just infra-init`
   - `just infra-plan`
   - `just infra-apply`
4. If using private admin access, enable the Tailscale pattern in [docs/tailscale.md](/Users/davidgriswold/Desktop/Althea/docs/tailscale.md).

## Telegram pairing vs allowlist

If the bot shows a pairing code after each redeploy, set numeric Telegram user IDs in Terraform:

- `openclaw_telegram_allow_from_user_ids = ["8649446913"]` (example)

On every boot, the VM startup script runs `git pull` then patches `openclaw/openclaw.json` to `dmPolicy: allowlist` and `allowFrom` to that list, so you are not blocked on `openclaw pairing approve` over SSH.

After changing this variable, run `terraform apply` and **reboot the instance** (updated metadata startup scripts do not re-run until restart).

## Security baseline

- Restrict `admin_source_ranges` to known operator IPs.
- Restrict public ingress CIDRs where possible.
- Keep OpenClaw private on loopback.
- Use Secret Manager for sensitive values.
- Prefer TLS endpoint (`enable_caddy_https=true`) if exposing VM endpoints publicly.
- Prefer Tailscale-only access and remove public DNS records if you do not need internet ingress.
- Keep `enable_iap_ssh = true` and IAP firewall source range `35.235.240.0/20` in place for SSH fallback.
- Telegram token can be sourced from `telegram-reasonable-dev-bot` into `/opt/althea/runtime/telegram.env`.
- Anthropic key can be sourced from `amplify-dev-bot-anthropic-api-openclaw` into `/opt/althea/runtime/inference.env`.
- GitHub App private key can be sourced from `amplify-bots-github-app-private-key` into `/opt/althea/runtime/github-app.pem`.
- GitHub App IDs can be set in Terraform and written into `/opt/althea/runtime/github.env`.
- GitHub PAT can be sourced from `github_pat` into `/opt/althea/runtime/github.env` as `GH_TOKEN`.
- Claude Code Anthropic key can be sourced from `amplify-dev-bot-anthropic-api-claude-code` into `/opt/althea/runtime/claude-code.env`.
- OpenClaw runtime state is persisted on disk at `openclaw/home` (mounted to `/root/.openclaw`).

Bootstrap helper:

- `scripts/bootstrap_gsm_secrets.sh` prompts for required keys and writes them as Secret Manager versions.
- GitHub App-specific runbook: [docs/github-app.md](/Users/davidgriswold/Desktop/Althea/docs/github-app.md)

IAP helper scripts:

- `scripts/install_gcloud_numpy.sh` installs NumPy into gcloud's Python for better IAP TCP upload performance.
- `scripts/gcloud_iap_ssh.sh` runs `gcloud compute ssh --tunnel-through-iap` and automatically runs `--troubleshoot` on failure.
