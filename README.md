# Althea

Althea is now a lightweight runtime/infra shell around self-hosted OpenClaw.

The GitHub queue path has been removed.  
Tasking is expected to happen directly through OpenClaw's native Telegram bot ("Claw Bot").

## Runtime behavior

- Runs OpenClaw gateway as the primary service.
- Telegram is handled natively by OpenClaw channels.
- No GitHub webhook ingestion.
- OpenClaw runtime state persists in `openclaw/home` (mounted as `/root/.openclaw`).

## Local run

1. Copy `.env.example` to `.env`.
2. Start stack: `just deploy`
3. Check gateway container is up: `just logs openclaw-gateway`

## OpenClaw + Telegram

Use OpenClaw's own Telegram channel configuration for command/control and approvals.

- Telegram/OpenClaw wiring notes: [docs/openclaw.md](/Users/davidgriswold/Desktop/Althea/docs/openclaw.md)
- GitHub App auth wiring notes: [docs/github-app.md](/Users/davidgriswold/Desktop/Althea/docs/github-app.md)
- Tailscale ops notes: [docs/tailscale.md](/Users/davidgriswold/Desktop/Althea/docs/tailscale.md)

## Infra

Terraform remains in `infra/terraform` for VM/network/secrets/runtime bootstrap.
