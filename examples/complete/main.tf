# -----------------------------------------------------------------------------
# Example: complete
#
# Full external HTTPS load balancer stack — static IP, NEG, backend service,
# HTTP→HTTPS redirect, Google-managed SSL cert, HTTPS forwarding rule, uptime
# checks, and monitoring dashboard. Also demonstrates attaching a Cloud Armor
# security policy created by terraform-google-cloud-armor.
# -----------------------------------------------------------------------------

module "cloud_armor" {
  source  = "nurdsoft/cloud-armor/google"
  version = "1.0.0"

  project_id = var.project_id
  name       = "${var.component}-armor-policy"
}

module "external_https_lb" {
  source = "../.."

  project_id             = var.project_id
  component              = var.component
  region                 = var.region
  cloud_run_service_name = var.cloud_run_service_name

  customer_domain      = var.customer_domain
  uptime_check_path    = var.uptime_check_path
  uptime_check_period  = var.uptime_check_period
  uptime_check_timeout = var.uptime_check_timeout

  security_policy_self_link = module.cloud_armor.self_link
}
