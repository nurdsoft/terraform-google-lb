variable "project_id" {
  description = "GCP project ID that owns the load balancer stack."
  type        = string
}

variable "component" {
  description = "Name prefix applied to every resource (e.g. \"frontend\" produces \"frontend-static-ip\", \"frontend-cloudrun-neg\", etc.)."
  type        = string
}

variable "region" {
  description = "GCP region for the Serverless NEG. Must match the region of the target Cloud Run service."
  type        = string
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service the Serverless NEG routes traffic to. The service itself is expected to be managed outside this module (e.g. by a CI/CD pipeline)."
  type        = string
}

variable "customer_domain" {
  description = "Public domain served by the load balancer (e.g. \"dev.agoapp.net\"). When empty, the module provisions only the HTTP redirect stack (static IP, NEG, backend, URL maps, HTTP proxy, port-80 forwarding rule) — HTTPS, uptime checks, and dashboard are all skipped."
  type        = string
  default     = ""
}

variable "ssl_domains" {
  description = "Domains attached to the managed SSL certificate. When null, defaults to [customer_domain, \"www.<customer_domain>\"]. Ignored when customer_domain is empty."
  type        = list(string)
  default     = null
}

variable "ssl_cert_name_suffix" {
  description = "Suffix appended to the SSL certificate name: \"<component>-<suffix>\". Kept configurable so existing certs can be preserved across module adoption (the AGO frontend uses \"cdn-ssl-cert-v2\")."
  type        = string
  default     = "cdn-ssl-cert-v2"
}

variable "security_policy_self_link" {
  description = "Optional Cloud Armor security policy self_link to attach to the backend service. When set, LB request logging is also enabled (required for Cloud Armor verdicts to surface in Cloud Logging)."
  type        = string
  default     = null
}

variable "enable_uptime_check" {
  description = "Create HTTPS + HTTP-redirect uptime checks for customer_domain. Requires customer_domain to be set; otherwise silently skipped."
  type        = bool
  default     = true
}

variable "uptime_check_path" {
  description = "HTTP path both uptime checks request."
  type        = string
  default     = "/"
}

variable "uptime_check_period" {
  description = "Uptime check frequency in seconds."
  type        = number
  default     = 300
}

variable "uptime_check_timeout" {
  description = "Uptime check per-request timeout in seconds."
  type        = number
  default     = 10
}

variable "enable_dashboard" {
  description = "Create a monitoring dashboard for the LB + uptime metrics. Requires customer_domain to be set; otherwise silently skipped."
  type        = bool
  default     = true
}

variable "dashboard_tiles" {
  description = "Tiles rendered on the monitoring dashboard. Each tile is placed left-to-right, wrapping when the row width exceeds 12 columns. Tile filters for loadbalancing.* and monitoring.googleapis.com/uptime_check.* metrics are auto-scoped to this module's URL map name and customer_domain."
  type = list(object({
    title           = string
    type            = string # "line_chart" or "scorecard"
    enabled         = bool
    width           = number
    height          = number
    metric_type     = string
    filter          = string
    unit_override   = optional(string)
    legend_template = optional(string)
    y_axis_label    = string
    gauge_bounds = optional(object({
      lower = number
      upper = number
    }))
  }))
  default = [
    {
      title         = "HTTPS Response Time"
      type          = "line_chart"
      enabled       = true
      width         = 6
      height        = 4
      metric_type   = "loadbalancing.googleapis.com/https/total_latencies"
      filter        = ""
      unit_override = "ms"
      y_axis_label  = "Response Time (ms)"
    },
    {
      title        = "Request Count"
      type         = "line_chart"
      enabled      = true
      width        = 6
      height       = 4
      metric_type  = "loadbalancing.googleapis.com/https/request_count"
      filter       = ""
      y_axis_label = "Requests/sec"
    },
    {
      title           = "Error Rate (4xx)"
      type            = "line_chart"
      enabled         = true
      width           = 6
      height          = 4
      metric_type     = "loadbalancing.googleapis.com/https/request_count"
      filter          = "metric.labels.response_code_class=\"400\""
      legend_template = "4xx Errors"
      y_axis_label    = "Client Errors/sec"
    },
    {
      title           = "Error Rate (5xx)"
      type            = "line_chart"
      enabled         = true
      width           = 6
      height          = 4
      metric_type     = "loadbalancing.googleapis.com/https/request_count"
      filter          = "metric.labels.response_code_class=\"500\""
      legend_template = "5xx Errors"
      y_axis_label    = "Client Errors/sec"
    },
    {
      title        = "Uptime Check Status"
      type         = "scorecard"
      enabled      = true
      width        = 6
      height       = 4
      metric_type  = "monitoring.googleapis.com/uptime_check/check_passed"
      filter       = ""
      y_axis_label = "Uptime Status"
      gauge_bounds = {
        lower = 0.0
        upper = 1.0
      }
    }
  ]
}
