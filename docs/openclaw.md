# OpenClaw Configuration (Althea)

OpenClaw is expected to be controlled directly through its native Telegram bot channel ("Claw Bot").

No Althea Telegram webhook endpoint is used in this model.

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
- `CLAUDE_CODE_MODEL=haiku`

Use this env file for the Claude Code runtime/process (keep it separate from OpenClaw inference env if you want clean key isolation).

Example compose wiring:

```yaml
services:
  openclaw:
    image: <openclaw-image>
    env_file:
      - /opt/althea/runtime/telegram.env
      - /opt/althea/runtime/inference.env
```

If you run a separate Claude Code sidecar/process, add:

```yaml
services:
  claude-code:
    image: <claude-code-image>
    env_file:
      - /opt/althea/runtime/claude-code.env
```

## Behavior

- Commands are issued directly in Telegram to OpenClaw.
- Althea app no longer mediates command ingestion.
