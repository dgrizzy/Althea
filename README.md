# Althea

Althea is now a lightweight runtime/infra shell around self-hosted OpenClaw.

The GitHub queue path has been removed.  
Tasking is expected to happen directly through OpenClaw's native Telegram bot ("Claw Bot").

## App behavior

- Exposes only `GET /healthz`.
- No GitHub webhook ingestion.
- No Telegram webhook ingestion.

## Local run

1. Copy `.env.example` to `.env`.
2. Start stack: `just deploy`
3. Check health: `curl http://localhost:8080/healthz`

## OpenClaw + Telegram

Use OpenClaw's own Telegram channel configuration for command/control and approvals.

- Telegram/OpenClaw wiring notes: [docs/openclaw.md](/Users/davidgriswold/Desktop/Althea/docs/openclaw.md)
- Tailscale ops notes: [docs/tailscale.md](/Users/davidgriswold/Desktop/Althea/docs/tailscale.md)

## Infra

Terraform remains in `infra/terraform` for VM/network/secrets/runtime bootstrap.
