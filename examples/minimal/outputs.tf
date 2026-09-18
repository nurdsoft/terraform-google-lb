output "static_ip_address" {
  description = "Reserved external IPv4."
  value       = module.lb.static_ip_address
}

output "backend_service_name" {
  description = "Name of the backend service."
  value       = module.lb.backend_service_name
}

output "url_map_name" {
  description = "Name of the main URL map."
  value       = module.lb.url_map_name
}
