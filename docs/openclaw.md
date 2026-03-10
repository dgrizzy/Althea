# OpenClaw Configuration (Althea)

Althea now dispatches directly to OpenClaw's native `/hooks/agent` contract.

## Required OpenClaw hook config

- Enable hooks in OpenClaw.
- Set a hook token.
- Allow the target agent ID used by Althea.

Suggested values:

- `hooks.enabled = true`
- `hooks.token = <same as OPENCLAW_HOOK_TOKEN>`
- `hooks.allowedAgentIds = ["main"]`
- `hooks.allowRequestSessionKey = false` (default path for this repo)

## Althea env alignment

Set in `.env`:

- `OPENCLAW_HOOK_URL=http://127.0.0.1:18789/hooks/agent`
- `OPENCLAW_HOOK_TOKEN=<hook token>`
- `OPENCLAW_HOOK_NAME=GitHub`
- `OPENCLAW_AGENT_ID=main`
- `OPENCLAW_HOOK_DELIVER=false`
- `OPENCLAW_WAKE_MODE=now`
- `OPENCLAW_ALLOW_REQUEST_SESSION_KEY=false`

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

Althea transforms a GitHub issue into a structured message string and sends:

- `message`
- `name`
- `wakeMode`
- `deliver`
- optional `agentId`
- optional `sessionKey` (only if `OPENCLAW_ALLOW_REQUEST_SESSION_KEY=true`)
