output "static_ip_address" {
  description = "Reserved external IPv4. Point the customer domain's A record here."
  value       = module.external_https_lb.static_ip_address
}

output "frontend_url" {
  description = "HTTPS URL served by the LB."
  value       = "https://${var.customer_domain}"
}

output "backend_service_name" {
  description = "Name of the backend service."
  value       = module.external_https_lb.backend_service_name
}

output "url_map_name" {
  description = "Name of the main URL map."
  value       = module.external_https_lb.url_map_name
}

output "dashboard_id" {
  description = "ID of the monitoring dashboard."
  value       = module.external_https_lb.dashboard_id
}

output "cloud_armor_policy_self_link" {
  description = "Self link of the Cloud Armor policy attached to the backend service."
  value       = module.cloud_armor.self_link
}
