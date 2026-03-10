# Operations

## Local lifecycle

- Deploy: `just deploy`
- Start: `just start`
- Stop: `just stop`
- Logs: `just logs`
- Infra init: `just infra-init`
- Infra plan: `just infra-plan`
- Infra apply: `just infra-apply`
- Infra destroy: `just infra-destroy`

## Health

- `GET /healthz` must return `{"status":"ok"}`.

## Security controls

- Keep OpenClaw private on loopback where possible.
- Use Telegram allowlists in OpenClaw so only your user can command the bot.
- Keep Telegram/OpenClaw provider API keys in Secret Manager.
- Keep exec approvals enabled for destructive actions.
- Keep Tailscale SSH/private admin access enabled; avoid broad public SSH CIDRs.
