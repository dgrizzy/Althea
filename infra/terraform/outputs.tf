output "vm_name" {
  value       = google_compute_instance.this.name
  description = "Althea VM name"
}

output "vm_external_ip" {
  value       = google_compute_address.this.address
  description = "Public static IP for ingress"
}

output "webhook_url" {
  value       = local.webhook_url
  description = "Webhook URL to configure in GitHub"
}

output "secret_ids" {
  value = {
    for key, secret in google_secret_manager_secret.this :
    key => secret.secret_id
  }
  description = "Created Secret Manager secret IDs"
}
