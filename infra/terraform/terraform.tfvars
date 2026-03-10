project_id                      = "amplify-bots"
region                          = "us-central1"
zone                            = "us-central1-a"
name_prefix                     = "amplify-bots"
machine_type                    = "e2-standard-2"
boot_disk_size_gb               = 40
service_port                    = 8080
expose_direct_service_port      = true
enable_caddy_https              = true
public_service_domain           = "bot.amplifydental.ai"
caddy_acme_email                = ""
caddy_acme_ca                   = "https://acme-v02.api.letsencrypt.org/directory"
enable_persistent_caddy_storage = true
caddy_data_disk_size_gb         = 10
caddy_data_disk_type            = "pd-balanced"

# Update these before apply.
admin_source_ranges   = ["203.0.113.10/32"]
service_source_ranges = ["0.0.0.0/0"]

ssh_username   = "amplify-admin"
ssh_public_key = ""

bootstrap_repo_url     = "https://github.com/dgrizzy/Althea.git"
bootstrap_repo_ref     = "main"
bootstrap_repo_dir     = "/opt/althea/app"
bootstrap_compose_file = "docker-compose.yml"

enable_tailscale             = true
tailscale_auth_key_secret_id = ""
tailscale_hostname           = "amplify-bots-vm"
tailscale_advertise_tags     = ["tag:amplify-bots"]
tailscale_ssh                = true
tailscale_accept_routes      = false

telegram_bot_token_secret_id = "telegram-reasonable-dev-bot"
write_telegram_env_file      = true
telegram_env_file_path       = "/opt/althea/runtime/telegram.env"

anthropic_api_key_secret_id = "amplify-dev-bot-anthropic-api-openclaw"
write_inference_env_file    = true
inference_env_file_path     = "/opt/althea/runtime/inference.env"
openclaw_primary_model      = "haiku"

claude_code_anthropic_api_key_secret_id = "amplify-dev-bot-anthropic-api-claude-code"
write_claude_code_env_file              = true
claude_code_env_file_path               = "/opt/althea/runtime/claude-code.env"
claude_code_model                       = "haiku"

create_secret_versions = false
initial_secret_keys    = []
initial_secret_values = {
  tailscale_auth_key = ""
}
