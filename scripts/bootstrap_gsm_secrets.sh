#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-amplify-bots}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd gcloud

ensure_secret() {
  local secret_name="$1"
  if ! gcloud secrets describe "$secret_name" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Creating secret: $secret_name"
    gcloud secrets create "$secret_name" --replication-policy="automatic" --project="$PROJECT_ID" >/dev/null
  fi
}

add_version_from_stdin() {
  local secret_name="$1"
  echo "Adding secret version: $secret_name"
  gcloud secrets versions add "$secret_name" --data-file=- --project="$PROJECT_ID" >/dev/null
}

add_prompted_secret() {
  local secret_name="$1"
  local prompt="$2"

  ensure_secret "$secret_name"
  read -r -s -p "$prompt: " value
  echo
  if [ -z "${value}" ]; then
    echo "Skipped $secret_name (empty input)"
    return
  fi
  printf '%s' "$value" | add_version_from_stdin "$secret_name"
}

add_multiline_secret() {
  local secret_name="$1"
  local prompt="$2"

  ensure_secret "$secret_name"
  echo "$prompt"
  echo "Finish input with a line containing only: EOF"

  local value=""
  while IFS= read -r line; do
    if [ "$line" = "EOF" ]; then
      break
    fi
    value+="${line}"$'\n'
  done

  if [ -z "${value}" ]; then
    echo "Skipped $secret_name (empty input)"
    return
  fi

  printf '%s' "$value" | add_version_from_stdin "$secret_name"
}

echo "Using project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID" >/dev/null

echo "\n[1/6] Tailscale auth key (from Tailscale admin console)"
add_prompted_secret "amplify-bots-tailscale-auth-key" "Enter tailscale auth key (tskey-...)"

echo "\n[2/6] Telegram bot token"
add_prompted_secret "telegram-reasonable-dev-bot" "Enter Telegram bot token"

echo "\n[3/6] Anthropic key for OpenClaw"
add_prompted_secret "amplify-dev-bot-anthropic-api-openclaw" "Enter Anthropic API key for OpenClaw"

echo "\n[4/6] Anthropic key for Claude Code"
add_prompted_secret "amplify-dev-bot-anthropic-api-claude-code" "Enter Anthropic API key for Claude Code"

echo "\n[5/6] GitHub App private key (PEM)"
add_multiline_secret "amplify-bots-github-app-private-key" "Paste full PEM including BEGIN/END lines"

echo "\n[6/6] OpenClaw gateway token (generated)"
ensure_secret "amplify-bots-openclaw-gateway-token"
python3 - <<'PY' | add_version_from_stdin "amplify-bots-openclaw-gateway-token"
import secrets
print(secrets.token_urlsafe(48), end="")
PY

echo "\nSummary (latest 3 versions each)"
for secret in \
  amplify-bots-tailscale-auth-key \
  telegram-reasonable-dev-bot \
  amplify-dev-bot-anthropic-api-openclaw \
  amplify-dev-bot-anthropic-api-claude-code \
  amplify-bots-github-app-private-key \
  amplify-bots-openclaw-gateway-token
  do
    echo "--- $secret"
    gcloud secrets versions list "$secret" --project="$PROJECT_ID" --limit=3 --format='table(name,state,createTime)'
done

echo "\nDone."
