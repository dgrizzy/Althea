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

- Reject invalid or missing `X-Hub-Signature-256`.
- Use least-privilege GitHub App for writeback.
- Keep OpenClaw webhook token secret.
- Target OpenClaw native endpoint `/hooks/agent`.
- Enable sender policy with `ALLOWED_GITHUB_SENDERS` and `BLOCKED_GITHUB_SENDERS`.
- Keep `ALLOW_BOT_SENDERS=false` unless bot dispatch is intentional.
- Keep replay TTL enabled to reject duplicate `X-GitHub-Delivery` IDs.
- Keep rate limiting enabled for `/webhooks/github`.
