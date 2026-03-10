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
require_cmd openssl

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

add_generated_hex_secret() {
  local secret_name="$1"
  local bytes="${2:-32}"
  ensure_secret "$secret_name"
  openssl rand -hex "$bytes" | add_version_from_stdin "$secret_name"
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

add_file_secret() {
  local secret_name="$1"
  local file_path="$2"

  ensure_secret "$secret_name"
  echo "Adding secret version from file for: $secret_name"
  gcloud secrets versions add "$secret_name" --data-file="$file_path" --project="$PROJECT_ID" >/dev/null
}

echo "Using project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID" >/dev/null

echo "\n[1/7] Generating and storing random webhook + hook tokens"
add_generated_hex_secret "amplify-bots-github-webhook-secret" 32
add_generated_hex_secret "amplify-bots-openclaw-hook-token" 32

echo "\n[2/7] Tailscale auth key (from Tailscale admin console)"
add_prompted_secret "amplify-bots-tailscale-auth-key" "Enter tailscale auth key (tskey-...)"

echo "\n[3/7] Telegram bot token"
add_prompted_secret "telegram-reasonable-dev-bot" "Enter Telegram bot token"

echo "\n[4/7] Anthropic key for OpenClaw"
add_prompted_secret "amplify-dev-bot-anthropic-api-openclaw" "Enter Anthropic API key for OpenClaw"

echo "\n[5/7] Anthropic key for Claude Code"
add_prompted_secret "amplify-dev-bot-anthropic-api-claude-code" "Enter Anthropic API key for Claude Code"

echo "\n[6/7] GitHub App private key PEM"
read -r -p "Path to GitHub App private key PEM file: " pem_path
if [ -n "${pem_path}" ] && [ -f "${pem_path}" ]; then
  add_file_secret "amplify-bots-github-app-private-key" "$pem_path"
else
  echo "Skipped GitHub private key (file not provided or missing)."
fi

echo "\n[7/7] Summary (latest 3 versions each)"
for secret in \
  amplify-bots-github-webhook-secret \
  amplify-bots-openclaw-hook-token \
  amplify-bots-tailscale-auth-key \
  amplify-bots-github-app-private-key \
  telegram-reasonable-dev-bot \
  amplify-dev-bot-anthropic-api-openclaw \
  amplify-dev-bot-anthropic-api-claude-code
  do
    echo "--- $secret"
    gcloud secrets versions list "$secret" --project="$PROJECT_ID" --limit=3 --format='table(name,state,createTime)'
done

echo "\nDone."
