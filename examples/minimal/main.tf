# -----------------------------------------------------------------------------
# Example: minimal
#
# HTTP-only stack — reserved static IP, Serverless NEG, backend service, main
# URL map, and HTTP redirect. HTTPS, uptime checks, and monitoring dashboard
# are all skipped because customer_domain is omitted. Useful for reserving
# the IP before DNS is ready.
# -----------------------------------------------------------------------------

module "external_https_lb" {
  source = "../.."

  project_id             = var.project_id
  component              = var.component
  region                 = var.region
  cloud_run_service_name = var.cloud_run_service_name
}
