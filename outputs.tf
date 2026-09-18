output "static_ip_address" {
  description = "Reserved external IPv4 address in front of the load balancer. Point the customer domain's A record here."
  value       = google_compute_global_address.static_ip.address
}

output "static_ip_name" {
  description = "Name of the reserved global address resource."
  value       = google_compute_global_address.static_ip.name
}

output "backend_service_id" {
  description = "ID of the Cloud Run backend service. Reference from Cloud Armor policies or additional URL maps."
  value       = google_compute_backend_service.cloudrun_backend.id
}

output "backend_service_name" {
  description = "Name of the Cloud Run backend service."
  value       = google_compute_backend_service.cloudrun_backend.name
}

output "url_map_name" {
  description = "Name of the main URL map. Use this in log sink filters (`resource.labels.url_map_name`) and alert-policy metric filters."
  value       = google_compute_url_map.main.name
}

output "url_map_id" {
  description = "ID of the main URL map."
  value       = google_compute_url_map.main.id
}

output "https_redirect_url_map_id" {
  description = "ID of the HTTP→HTTPS redirect URL map."
  value       = google_compute_url_map.https_redirect.id
}

output "ssl_certificate_id" {
  description = "ID of the managed SSL certificate. Null when customer_domain is empty."
  value       = length(google_compute_managed_ssl_certificate.ssl_cert) > 0 ? google_compute_managed_ssl_certificate.ssl_cert[0].id : null
}

output "dashboard_id" {
  description = "ID of the monitoring dashboard. Null when enable_dashboard is false or customer_domain is empty."
  value       = length(google_monitoring_dashboard.frontend) > 0 ? google_monitoring_dashboard.frontend[0].id : null
}

output "https_uptime_check_id" {
  description = "ID of the HTTPS uptime check. Null when enable_uptime_check is false or customer_domain is empty."
  value       = length(google_monitoring_uptime_check_config.https) > 0 ? google_monitoring_uptime_check_config.https[0].id : null
}

output "http_redirect_uptime_check_id" {
  description = "ID of the HTTP redirect uptime check. Null when enable_uptime_check is false or customer_domain is empty."
  value       = length(google_monitoring_uptime_check_config.http_redirect) > 0 ? google_monitoring_uptime_check_config.http_redirect[0].id : null
}
