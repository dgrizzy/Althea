# Althea

Althea is a GitHub-native ingress service that validates GitHub webhooks, normalizes approved issue tasks, and dispatches them to OpenClaw.

## Quick start

1. Copy `.env.example` to `.env` and fill secrets.
2. Run `just deploy`.
3. Check `http://localhost:8080/healthz`.

OpenClaw hook target should be the native agent endpoint:
- `OPENCLAW_HOOK_URL=http://<openclaw-host>:18789/hooks/agent`

Recommended security envs:
- `RATE_LIMIT_ENABLED=true`
- `DELIVERY_REPLAY_TTL_SECONDS=3600`
- `ALLOW_BOT_SENDERS=false`
- `ALLOWED_GITHUB_SENDERS=<optional csv allowlist>`

## Top-level control file

Use `just`:

- `just deploy` - build and start services
- `just start` - start services
- `just stop` - stop services
- `just logs` - tail logs
- `just test` - run tests
- `just infra-init` - initialize Terraform in `infra/terraform`
- `just infra-plan` - plan infra changes
- `just infra-apply` - apply infra changes
- `just infra-destroy` - destroy infra

## Infrastructure

Terraform lives in `infra/terraform`.

Quick start:

1. `cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars`
2. Edit values in `infra/terraform/terraform.tfvars`
3. `just infra-init`
4. `just infra-plan`
5. `just infra-apply`

Tailscale deployment pattern:
- [docs/tailscale.md](/Users/davidgriswold/Desktop/Althea/docs/tailscale.md)

GitHub secure channel checklist:
- [docs/github-secure-channel.md](/Users/davidgriswold/Desktop/Althea/docs/github-secure-channel.md)

OpenClaw runtime secret wiring:
- [docs/openclaw.md](/Users/davidgriswold/Desktop/Althea/docs/openclaw.md)
