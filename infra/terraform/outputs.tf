output "vm_name" {
  value       = google_compute_instance.this.name
  description = "Althea VM name"
}

output "vm_external_ip" {
  value       = google_compute_address.this.address
  description = "Public static IP for ingress"
}

output "service_url" {
  value       = local.service_url
  description = "Service URL. If public ingress is disabled, this is the localhost tunnel URL."
}

output "secret_ids" {
  value = {
    for key, secret in google_secret_manager_secret.this :
    key => secret.secret_id
  }
  description = "Created Secret Manager secret IDs"
}

output "caddy_data_disk_name" {
  value       = try(google_compute_disk.caddy_data[0].name, null)
  description = "Persistent disk name used for Caddy cert/state storage"
}
