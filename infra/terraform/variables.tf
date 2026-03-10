variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "amplify-bots"
}

variable "machine_type" {
  description = "VM machine type"
  type        = string
  default     = "e2-standard-2"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 40
}

variable "boot_disk_image" {
  description = "Boot disk image"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "admin_source_ranges" {
  description = "CIDR ranges allowed for SSH admin access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "service_source_ranges" {
  description = "CIDR ranges allowed to reach the public service endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "service_port" {
  description = "TCP port where the app is exposed when using direct ingress"
  type        = number
  default     = 8080
}

variable "expose_direct_service_port" {
  description = "Expose direct service port on VM firewall"
  type        = bool
  default     = true
}

variable "enable_caddy_https" {
  description = "Install and configure Caddy for HTTPS reverse proxy to service_port"
  type        = bool
  default     = false
}

variable "public_service_domain" {
  description = "Public DNS host for service endpoint, e.g. bot.example.com"
  type        = string
  default     = ""
}

variable "caddy_acme_email" {
  description = "Optional ACME email for certificate registration"
  type        = string
  default     = ""
}

variable "caddy_acme_ca" {
  description = "ACME directory URL used by Caddy for certificate issuance"
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "enable_persistent_caddy_storage" {
  description = "Attach and mount a dedicated persistent disk at /var/lib/caddy so cert state survives VM recreation"
  type        = bool
  default     = true
}

variable "caddy_data_disk_size_gb" {
  description = "Size of dedicated persistent disk for Caddy state"
  type        = number
  default     = 10
}

variable "caddy_data_disk_type" {
  description = "Disk type for dedicated persistent Caddy state disk"
  type        = string
  default     = "pd-balanced"
}

variable "ssh_username" {
  description = "Username for injected SSH public key"
  type        = string
  default     = "amplify-admin"
}

variable "ssh_public_key" {
  description = "Optional SSH public key for VM access"
  type        = string
  default     = ""
}

variable "instance_metadata" {
  description = "Additional instance metadata"
  type        = map(string)
  default     = {}
}

variable "bootstrap_repo_url" {
  description = "Optional Git URL for initial checkout on VM. If set, startup script clones the repo and runs compose; if empty, you deploy the stack manually."
  type        = string
  default     = ""
}

variable "bootstrap_repo_ref" {
  description = "Git ref/branch to checkout"
  type        = string
  default     = "main"
}

variable "bootstrap_repo_dir" {
  description = "Directory where repo will be checked out"
  type        = string
  default     = "/opt/althea/app"
}

variable "bootstrap_compose_file" {
  description = "Path to docker-compose file relative to bootstrap_repo_dir"
  type        = string
  default     = "docker-compose.yml"
}

variable "create_secret_versions" {
  description = "Whether to create initial Secret Manager secret versions"
  type        = bool
  default     = false
}

variable "initial_secret_keys" {
  description = "Which secret keys to create initial versions for (subset of initial_secret_values keys). Use with create_secret_versions = true."
  type        = set(string)
  default     = []
}

variable "initial_secret_values" {
  description = "Initial values for known secrets (optional). Keys: tailscale_auth_key"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "enable_tailscale" {
  description = "Install and configure tailscaled on VM startup"
  type        = bool
  default     = false
}

variable "tailscale_auth_key_secret_id" {
  description = "Secret Manager secret ID containing Tailscale auth key (defaults to <name_prefix>-tailscale-auth-key)"
  type        = string
  default     = ""
}

variable "tailscale_hostname" {
  description = "Hostname to register in Tailnet"
  type        = string
  default     = ""
}

variable "tailscale_advertise_tags" {
  description = "Tailscale ACL tags to advertise (e.g. [\"tag:althea\"])"
  type        = list(string)
  default     = []
}

variable "tailscale_ssh" {
  description = "Enable Tailscale SSH on the VM"
  type        = bool
  default     = true
}

variable "tailscale_accept_routes" {
  description = "Whether to accept subnet routes from other nodes"
  type        = bool
  default     = false
}

variable "telegram_bot_token_secret_id" {
  description = "Existing Secret Manager secret ID containing Telegram bot token for OpenClaw"
  type        = string
  default     = "telegram-reasonable-dev-bot"
}

variable "write_telegram_env_file" {
  description = "Write TELEGRAM_BOT_TOKEN into a locked-down env file on VM startup"
  type        = bool
  default     = true
}

variable "telegram_env_file_path" {
  description = "Absolute path for generated Telegram token env file"
  type        = string
  default     = "/opt/althea/runtime/telegram.env"
}

variable "anthropic_api_key_secret_id" {
  description = "Existing Secret Manager secret ID containing Anthropic API key for OpenClaw inference"
  type        = string
  default     = "amplify-dev-bot-anthropic-api-openclaw"
}

variable "write_inference_env_file" {
  description = "Write Anthropic inference env vars into a locked-down env file on VM startup"
  type        = bool
  default     = true
}

variable "inference_env_file_path" {
  description = "Absolute path for generated inference env file"
  type        = string
  default     = "/opt/althea/runtime/inference.env"
}

variable "openclaw_primary_model" {
  description = "Primary model identifier hint for OpenClaw runtime (set to your preferred Haiku model id)"
  type        = string
  default     = "haiku"
}

variable "claude_code_anthropic_api_key_secret_id" {
  description = "Existing Secret Manager secret ID containing Anthropic API key used by Claude Code workloads"
  type        = string
  default     = "amplify-dev-bot-anthropic-api-claude-code"
}

variable "write_claude_code_env_file" {
  description = "Write Claude Code Anthropic env vars into a locked-down env file on VM startup"
  type        = bool
  default     = true
}

variable "claude_code_env_file_path" {
  description = "Absolute path for generated Claude Code env file"
  type        = string
  default     = "/opt/althea/runtime/claude-code.env"
}

variable "claude_code_model" {
  description = "Default model identifier hint for Claude Code runtime (set to your preferred Haiku model id)"
  type        = string
  default     = "haiku"
}

variable "vm_oauth_scopes" {
  description = "OAuth scopes for VM service account. CE only supports a limited scope set; Secret Manager requires cloud-platform. Least-privilege is enforced via IAM roles (secretAccessor, logWriter)."
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}
