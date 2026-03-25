# OpenClaw Configuration (Althea)

OpenClaw is expected to be controlled directly through its native Telegram bot channel ("Claw Bot").

No Althea Telegram webhook endpoint is used in this model.

The runtime stack now includes an `openclaw-gateway` service in [docker-compose.yml](../docker-compose.yml).
Gateway port defaults to `18789`.

For the VM deployment, the Docker-published port is expected to stay on host
loopback and be exposed to browsers through Tailscale Serve HTTPS, not direct
tailnet HTTP.

## Persistence model

OpenClaw runtime state is persisted outside the container filesystem via:

- `OPENCLAW_HOME_DIR` (default `./openclaw/home`) mounted at `/root/.openclaw`

This keeps memory/session history/workspace and channel credentials durable across
container restarts/recreates.

### GCP / Terraform (recommended)

Terraform can attach a **dedicated persistent disk** for OpenClaw state so it survives
**VM replacement** (boot disk wipe). See `enable_persistent_openclaw_storage` and
`openclaw_data_mount_path` in [infra/terraform/variables.tf](../infra/terraform/variables.tf).
The VM startup script mounts the disk (default `/mnt/openclaw-data`) and rewrites
`.env` to `OPENCLAW_HOME_DIR=/mnt/openclaw-data/home`, migrating any existing data
from `${bootstrap_repo_dir}/openclaw/home` once.

Optional: `enable_openclaw_home_backup_timer` installs a **daily systemd timer** that
runs [scripts/backup-openclaw-home.sh](../scripts/backup-openclaw-home.sh) into
`/mnt/openclaw-data/backups/`.

### Manual backup/restore (on VM)

```bash
tar -czf /opt/althea/runtime/openclaw-home-backup.tgz -C /opt/althea/app openclaw/home
```

With persistent disk (typical after Terraform defaults):

```bash
./scripts/backup-openclaw-home.sh
# or inspect /mnt/openclaw-data/backups/openclaw-home-*.tgz
```

## Required OpenClaw runtime config

- Enable Telegram channel integration in OpenClaw.
- Restrict allowed Telegram user IDs to your account(s).
- Keep exec approvals enabled for risky actions.
- Keep `gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback` disabled.

Suggested values (conceptual):

- `telegram.enabled = true`
- `telegram.allowFrom = ["<your_telegram_user_id>"]` with `telegram.dmPolicy = "allowlist"` (pairing is the default in-repo; production can set IDs via Terraform — see [docs/infra.md](infra.md#telegram-pairing-vs-allowlist))
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

The image now pins known-good OpenClaw and Claude Code versions in
[docker/openclaw.Dockerfile](/Users/davidgriswold/Desktop/Althea/docker/openclaw.Dockerfile) so rebuilds stay reproducible.

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
