# Infra

Althea infrastructure is provisioned via Terraform under `infra/terraform`.

## What it creates

- VPC and subnet
- Firewall rules for SSH and webhook ingress
- Static IP for webhook endpoint
- Compute Engine VM for runtime
- VM service account and IAM bindings
- Secret Manager secret containers

## Standard flow

1. Copy `infra/terraform/terraform.tfvars.example` to `infra/terraform/terraform.tfvars`.
2. Set `project_id`, `admin_source_ranges`, `webhook_source_ranges`, and `bootstrap_repo_url`.
   If using HTTPS webhook endpoint, also set `enable_caddy_https=true` and `public_webhook_domain`.
3. Run:
   - `just infra-init`
   - `just infra-plan`
   - `just infra-apply`
4. Capture the Terraform output `webhook_url` and configure it in GitHub webhooks.
5. If using private admin access, enable the Tailscale pattern in [docs/tailscale.md](/Users/davidgriswold/Desktop/Althea/docs/tailscale.md).

## Security baseline

- Restrict `admin_source_ranges` to known operator IPs.
- Restrict `webhook_source_ranges` to trusted CIDRs.
- Keep OpenClaw private on loopback and expose only Althea ingress.
- Use Secret Manager for sensitive values.
- Prefer TLS endpoint (`enable_caddy_https=true`) and disable direct webhook port exposure after cutover.
- Telegram token can be sourced from `telegram-reasonable-dev-bot` into `/opt/althea/runtime/telegram.env`.
- Anthropic key can be sourced from `amplify-dev-bot-anthropic-api-openclaw` into `/opt/althea/runtime/inference.env`.
- Claude Code Anthropic key can be sourced from `amplify-dev-bot-anthropic-api-claude-code` into `/opt/althea/runtime/claude-code.env`.

Bootstrap helper:

- `scripts/bootstrap_gsm_secrets.sh` generates random webhook/hook tokens and prompts for provider-issued keys, then writes all values as Secret Manager versions.
