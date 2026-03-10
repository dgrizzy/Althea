provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

locals {
  network_name    = "${var.name_prefix}-vpc"
  subnet_name     = "${var.name_prefix}-subnet"
  vm_name         = "${var.name_prefix}-vm"
  service_account = "${var.name_prefix}-vm-sa"
  caddy_data_disk = "${var.name_prefix}-caddy-data"

  required_services = toset([
    "compute.googleapis.com",
    "secretmanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
  ])

  secret_ids = {
    tailscale_auth_key = "${var.name_prefix}-tailscale-auth-key"
  }

  merged_metadata = merge(
    {
      enable-oslogin = "TRUE"
    },
    var.instance_metadata,
    var.ssh_public_key == "" ? {} : {
      ssh-keys = "${var.ssh_username}:${var.ssh_public_key}"
    }
  )

  service_url = (
    var.enable_caddy_https && var.public_service_domain != ""
    ? "https://${var.public_service_domain}/healthz"
    : "http://${google_compute_address.this.address}:${var.service_port}/healthz"
  )
}

resource "google_project_service" "required" {
  for_each           = local.required_services
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "this" {
  name                    = local.network_name
  auto_create_subnetworks = false

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "this" {
  name          = local.subnet_name
  ip_cidr_range = "10.50.0.0/24"
  region        = var.region
  network       = google_compute_network.this.id
}

resource "google_compute_firewall" "allow_ssh" {
  name          = "${var.name_prefix}-allow-ssh"
  network       = google_compute_network.this.name
  source_ranges = var.admin_source_ranges
  target_tags   = ["althea-vm"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_service" {
  count         = var.expose_direct_service_port ? 1 : 0
  name          = "${var.name_prefix}-allow-service"
  network       = google_compute_network.this.name
  source_ranges = var.service_source_ranges
  target_tags   = ["althea-vm"]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.service_port)]
  }
}

resource "google_compute_firewall" "allow_service_https" {
  count         = var.enable_caddy_https ? 1 : 0
  name          = "${var.name_prefix}-allow-service-https"
  network       = google_compute_network.this.name
  source_ranges = var.service_source_ranges
  target_tags   = ["althea-vm"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_address" "this" {
  name   = "${var.name_prefix}-ip"
  region = var.region
}

resource "google_compute_disk" "caddy_data" {
  count = var.enable_caddy_https && var.enable_persistent_caddy_storage ? 1 : 0

  name = local.caddy_data_disk
  zone = var.zone
  type = var.caddy_data_disk_type
  size = var.caddy_data_disk_size_gb
}

resource "google_service_account" "vm" {
  account_id   = local.service_account
  display_name = "${var.name_prefix} VM Service Account"

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "vm_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_project_iam_member" "vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_secret_manager_secret" "this" {
  for_each  = local.secret_ids
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "initial" {
  for_each = var.create_secret_versions ? toset([for k in var.initial_secret_keys : k if contains(keys(local.secret_ids), k)]) : []

  secret      = google_secret_manager_secret.this[each.key].id
  secret_data = var.initial_secret_values[each.key]
}

resource "google_compute_instance" "this" {
  name                      = local.vm_name
  machine_type              = var.machine_type
  zone                      = var.zone
  tags                      = ["althea-vm"]
  metadata                  = local.merged_metadata
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.this.id

    access_config {
      nat_ip = google_compute_address.this.address
    }
  }

  dynamic "attached_disk" {
    for_each = var.enable_caddy_https && var.enable_persistent_caddy_storage ? [1] : []
    content {
      source      = google_compute_disk.caddy_data[0].id
      mode        = "READ_WRITE"
      device_name = google_compute_disk.caddy_data[0].name
    }
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = var.vm_oauth_scopes
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup.sh.tmpl", {
    project_id                              = var.project_id
    bootstrap_repo_url                      = var.bootstrap_repo_url
    bootstrap_repo_ref                      = var.bootstrap_repo_ref
    bootstrap_repo_dir                      = var.bootstrap_repo_dir
    bootstrap_compose_file                  = var.bootstrap_compose_file
    enable_tailscale                        = var.enable_tailscale
    tailscale_auth_key_secret_id            = var.tailscale_auth_key_secret_id != "" ? var.tailscale_auth_key_secret_id : local.secret_ids["tailscale_auth_key"]
    tailscale_hostname                      = var.tailscale_hostname != "" ? var.tailscale_hostname : local.vm_name
    tailscale_advertise_tags                = join(",", var.tailscale_advertise_tags)
    tailscale_ssh                           = var.tailscale_ssh
    tailscale_accept_routes                 = var.tailscale_accept_routes
    enable_caddy_https                      = var.enable_caddy_https
    public_service_domain                   = var.public_service_domain
    caddy_acme_email                        = var.caddy_acme_email
    caddy_acme_ca                           = var.caddy_acme_ca
    enable_persistent_caddy_storage         = var.enable_persistent_caddy_storage
    caddy_data_disk_name                    = local.caddy_data_disk
    service_port                            = var.service_port
    telegram_bot_token_secret_id            = var.telegram_bot_token_secret_id
    write_telegram_env_file                 = var.write_telegram_env_file
    telegram_env_file_path                  = var.telegram_env_file_path
    anthropic_api_key_secret_id             = var.anthropic_api_key_secret_id
    write_inference_env_file                = var.write_inference_env_file
    inference_env_file_path                 = var.inference_env_file_path
    openclaw_primary_model                  = var.openclaw_primary_model
    claude_code_anthropic_api_key_secret_id = var.claude_code_anthropic_api_key_secret_id
    write_claude_code_env_file              = var.write_claude_code_env_file
    claude_code_env_file_path               = var.claude_code_env_file_path
    claude_code_model                       = var.claude_code_model
  })

  depends_on = [
    google_project_service.required,
    google_project_iam_member.vm_secret_accessor,
    google_project_iam_member.vm_log_writer,
    google_compute_disk.caddy_data,
    google_compute_firewall.allow_service,
    google_compute_firewall.allow_service_https,
  ]
}
