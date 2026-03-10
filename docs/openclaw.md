# OpenClaw Configuration (Althea)

OpenClaw is expected to be controlled directly through its native Telegram bot channel ("Claw Bot").

No Althea Telegram webhook endpoint is used in this model.

The runtime stack now includes an `openclaw-gateway` service in [docker-compose.yml](/Users/davidgriswold/Desktop/Althea/docker-compose.yml).
Gateway port defaults to `18789`.

## Persistence model

OpenClaw runtime state is persisted outside the container filesystem via:

- `OPENCLAW_HOME_DIR` (default `./openclaw/home`) mounted at `/root/.openclaw`

This keeps memory/session history/workspace and channel credentials durable across
container restarts/recreates.

Backup/restore example (on VM):

```bash
tar -czf /opt/althea/runtime/openclaw-home-backup.tgz -C /opt/althea/app openclaw/home
```

## Required OpenClaw runtime config

- Enable Telegram channel integration in OpenClaw.
- Restrict allowed Telegram user IDs to your account(s).
- Keep exec approvals enabled for risky actions.

Suggested values (conceptual):

- `telegram.enabled = true`
- `telegram.allowedUsers = [<your_telegram_user_id>]`
- `approvals.exec = true`

## Telegram bot token from Secret Manager

With current Terraform defaults, VM startup fetches secret:

- `telegram-reasonable-dev-bot`

and writes:

- `/opt/althea/runtime/telegram.env`

with:

- `TELEGRAM_BOT_TOKEN=<token>`

Use this env file in your OpenClaw runtime (compose/systemd) instead of hardcoding token in config files.

## Anthropic inference key + Haiku model from Secret Manager

With current Terraform defaults, VM startup fetches secret:

- `amplify-dev-bot-anthropic-api-openclaw`

and writes:

- `/opt/althea/runtime/inference.env`

with:

- `ANTHROPIC_API_KEY=<key>`
- `OPENCLAW_PRIMARY_MODEL=haiku`

Use this env file in your OpenClaw runtime and map model configuration to `OPENCLAW_PRIMARY_MODEL` (or set the exact Haiku model id directly in OpenClaw config).

## Claude Code Anthropic key + Haiku model from Secret Manager

With current Terraform defaults, VM startup fetches secret:

- `amplify-dev-bot-anthropic-api-claude-code`

and writes:

- `/opt/althea/runtime/claude-code.env`

with:

- `ANTHROPIC_API_KEY=<key>`
- `ANTHROPIC_MODEL=haiku`
- `CLAUDE_CODE_MODEL=haiku`
- `CLAUDE_CODE_SUBAGENT_MODEL=haiku`

Use this env file for the Claude Code runtime/process (keep it separate from OpenClaw inference env if you want clean key isolation).

The container image installs `@anthropic-ai/claude-code`, which exposes the `claude` CLI
expected by OpenClaw's `coding-agent` skill.

Additional gateway env is written to:

- `/opt/althea/runtime/openclaw.env`

with:

- `OPENCLAW_GATEWAY_TOKEN=<token>`
- `GOG_KEYRING_PASSWORD=<token>`
- `OPENCLAW_GATEWAY_BIND=lan`
- `OPENCLAW_GATEWAY_PORT=18789`

If secret lookup is unavailable, startup will generate a local token once and reuse it from this file.

## GitHub auth for `gh` skill (PAT or App)

OpenClaw's bundled `github` skill requires `gh` CLI. The container image now installs `gh`.

At runtime, VM startup can materialize:

- `/opt/althea/runtime/github.env`
- `/opt/althea/runtime/github-app.pem`

with:

- `GITHUB_PAT=<pat>` (optional)
- `GH_TOKEN=<pat>` (optional; set from PAT)
- `GITHUB_TOKEN=<pat>` (optional; set from PAT)
- `GITHUB_APP_ID=<app-id>`
- `GITHUB_INSTALLATION_ID=<installation-id>`
- `GITHUB_APP_PRIVATE_KEY_PATH=/opt/althea/runtime/github-app.pem`

`gh` wrapper precedence is:

1. Use `GH_TOKEN`/`GITHUB_TOKEN`/`GITHUB_PAT` if present.
2. Otherwise mint a fresh installation token from GitHub App credentials.

This lets you run PAT-first now, then move to App auth later without changing container wiring.

## Behavior

- Commands are issued directly in Telegram to OpenClaw.
- Althea app no longer mediates command ingestion.
