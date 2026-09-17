# -----------------------------------------------------------------------------
# External HTTPS Load Balancer for Cloud Run
#
# Provisions the full LB stack for a single Cloud Run service reached from the
# public internet: reserved static IP, Serverless NEG, backend service, main
# URL map, HTTP→HTTPS redirect URL map, HTTP/HTTPS target proxies, managed SSL
# certificate, port-80/443 forwarding rules, optional uptime checks, and an
# optional monitoring dashboard.
#
# Optional Cloud Armor attachment: pass security_policy_self_link to attach a
# policy to the backend service (also enables LB request logging so Cloud
# Armor verdicts appear in Cloud Logging).
# -----------------------------------------------------------------------------

locals {
  domain_set = var.customer_domain != ""

  effective_ssl_domains = var.ssl_domains != null ? var.ssl_domains : [
    var.customer_domain,
    "www.${var.customer_domain}",
  ]

  waf_attached = var.security_policy_self_link != null

  create_ssl_stack = local.domain_set
  create_uptime    = var.enable_uptime_check && local.domain_set
  create_dashboard = var.enable_dashboard && local.domain_set

  enabled_tiles_data = [
    for tile in var.dashboard_tiles : tile
    if tile.enabled
  ]

  columns_per_row = 12

  enabled_tiles = [
    for i, tile in local.enabled_tiles_data : {
      width  = tile.width
      height = tile.height
      xPos   = i == 0 ? 0 : (sum([for j in range(i) : local.enabled_tiles_data[j].width]) % local.columns_per_row)
      yPos   = i == 0 ? 0 : floor(sum([for j in range(i) : local.enabled_tiles_data[j].width]) / local.columns_per_row) * 4
      widget = {
        title = tile.title
        scorecard = tile.type == "scorecard" ? {
          timeSeriesQuery = {
            timeSeriesFilter = {
              filter = join(" AND ", compact([
                tile.filter != "" ? tile.filter : null,
                "metric.type=\"${tile.metric_type}\"",
                startswith(tile.metric_type, "loadbalancing.googleapis.com/https/") ? "resource.type=\"https_lb_rule\"" : null,
                startswith(tile.metric_type, "loadbalancing.googleapis.com/https/") ? "resource.labels.url_map_name=\"${google_compute_url_map.main.name}\"" : null,
                startswith(tile.metric_type, "monitoring.googleapis.com/uptime_check/") ? "resource.type=\"uptime_url\"" : null,
                startswith(tile.metric_type, "monitoring.googleapis.com/uptime_check/") ? "resource.labels.host=\"${var.customer_domain}\"" : null
              ]))
            }
          }
          gaugeView = tile.gauge_bounds != null ? {
            lowerBound = tile.gauge_bounds.lower
            upperBound = tile.gauge_bounds.upper
          } : null
        } : null

        xyChart = tile.type == "line_chart" ? {
          chartOptions = tile.metric_type == "loadbalancing.googleapis.com/https/total_latencies" ? {
            mode = "COLOR"
          } : null
          dataSets = [{
            minAlignmentPeriod = tile.metric_type == "loadbalancing.googleapis.com/https/total_latencies" ? "60s" : null
            plotType           = "LINE"
            timeSeriesQuery = tile.metric_type == "loadbalancing.googleapis.com/https/total_latencies" ? {
              timeSeriesFilter = {
                aggregation = {
                  crossSeriesReducer = "REDUCE_SUM"
                  groupByFields = [
                    "resource.label.\"url_map_name\""
                  ]
                  perSeriesAligner = "ALIGN_PERCENTILE_99"
                }
                filter               = "metric.type=\"loadbalancing.googleapis.com/https/total_latencies\" resource.type=\"https_lb_rule\" resource.labels.url_map_name=\"${google_compute_url_map.main.name}\""
                secondaryAggregation = {}
              }
              unitOverride = "ms"
              } : {
              timeSeriesFilter = {
                aggregation = null
                filter = join(" AND ", compact([
                  tile.filter != "" ? tile.filter : null,
                  "metric.type=\"${tile.metric_type}\"",
                  startswith(tile.metric_type, "loadbalancing.googleapis.com/https/") ? "resource.type=\"https_lb_rule\"" : null,
                  startswith(tile.metric_type, "loadbalancing.googleapis.com/https/") ? "resource.labels.url_map_name=\"${google_compute_url_map.main.name}\"" : null,
                  startswith(tile.metric_type, "monitoring.googleapis.com/uptime_check/") ? "resource.type=\"uptime_url\"" : null,
                  startswith(tile.metric_type, "monitoring.googleapis.com/uptime_check/") ? "resource.labels.host=\"${var.customer_domain}\"" : null
                ]))
                secondaryAggregation = null
              }
              unitOverride = tile.unit_override
            }
            targetAxis     = "Y1"
            legendTemplate = tile.legend_template
          }]
          timeshiftDuration = tile.metric_type == "loadbalancing.googleapis.com/https/total_latencies" ? "0s" : null
          yAxis = {
            label = tile.y_axis_label
            scale = "LINEAR"
          }
          xAxis = {
            scale = "LINEAR"
          }
        } : null
      }
    }
  ]
}

# -----------------------------------------------------------------------------
# Static IP + Serverless NEG + Backend service
# -----------------------------------------------------------------------------

resource "google_compute_global_address" "static_ip" {
  project = var.project_id
  name    = "${var.component}-static-ip"
}

# Cloud Run service itself is expected to be managed by the CI/CD pipeline;
# the NEG only needs its name to route traffic.
resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  project               = var.project_id
  name                  = "${var.component}-cloudrun-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = var.cloud_run_service_name
  }
}

resource "google_compute_backend_service" "cloudrun_backend" {
  project               = var.project_id
  name                  = "${var.component}-cloudrun-backend"
  load_balancing_scheme = "EXTERNAL"

  security_policy = var.security_policy_self_link

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun_neg.id
  }

  # Required for Cloud Armor verdicts to surface in Cloud Logging.
  dynamic "log_config" {
    for_each = local.waf_attached ? [1] : []
    content {
      enable      = true
      sample_rate = 1.0
    }
  }
}

# -----------------------------------------------------------------------------
# URL maps + HTTP redirect stack (always created)
# -----------------------------------------------------------------------------

resource "google_compute_url_map" "main" {
  project         = var.project_id
  name            = "${var.component}-url-map"
  default_service = google_compute_backend_service.cloudrun_backend.id
}

resource "google_compute_url_map" "https_redirect" {
  project = var.project_id
  name    = "${var.component}-https-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "http_proxy" {
  project = var.project_id
  name    = "${var.component}-http-proxy"
  url_map = google_compute_url_map.https_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  project    = var.project_id
  name       = "${var.component}-http-rule"
  ip_address = google_compute_global_address.static_ip.address
  target     = google_compute_target_http_proxy.http_proxy.id
  port_range = "80"
}

# -----------------------------------------------------------------------------
# HTTPS stack (created only when customer_domain is set)
# -----------------------------------------------------------------------------

resource "google_compute_managed_ssl_certificate" "ssl_cert" {
  count   = local.create_ssl_stack ? 1 : 0
  project = var.project_id
  name    = "${var.component}-${var.ssl_cert_name_suffix}"
  managed {
    domains = local.effective_ssl_domains
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "https_proxy" {
  count            = local.create_ssl_stack ? 1 : 0
  project          = var.project_id
  name             = "${var.component}-https-proxy"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_cert[0].self_link]
}

resource "google_compute_global_forwarding_rule" "https" {
  count                 = local.create_ssl_stack ? 1 : 0
  project               = var.project_id
  name                  = "${var.component}-https-rule"
  ip_address            = google_compute_global_address.static_ip.address
  target                = google_compute_target_https_proxy.https_proxy[0].id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL"
}

# -----------------------------------------------------------------------------
# Uptime checks (optional; require customer_domain)
# -----------------------------------------------------------------------------

resource "google_monitoring_uptime_check_config" "https" {
  count        = local.create_uptime ? 1 : 0
  project      = var.project_id
  display_name = "${var.component}-https-uptime-check"
  http_check {
    port           = 443
    use_ssl        = true
    path           = var.uptime_check_path
    request_method = "GET"
    headers = {
      "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    }
    validate_ssl = true
  }
  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.customer_domain
    }
  }
  timeout = "${var.uptime_check_timeout}s"
  period  = "${var.uptime_check_period}s"
  content_matchers {
    content = ".*"
    matcher = "MATCHES_REGEX"
  }
}

resource "google_monitoring_uptime_check_config" "http_redirect" {
  count        = local.create_uptime ? 1 : 0
  project      = var.project_id
  display_name = "${var.component}-http-redirect-uptime-check"
  http_check {
    port           = 80
    use_ssl        = false
    path           = var.uptime_check_path
    request_method = "GET"
    headers = {
      "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    }
    validate_ssl = false
  }
  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.customer_domain
    }
  }
  timeout = "${var.uptime_check_timeout}s"
  period  = "${var.uptime_check_period}s"
  content_matchers {
    content = ".*"
    matcher = "MATCHES_REGEX"
  }
}

# -----------------------------------------------------------------------------
# Monitoring dashboard (optional; requires customer_domain)
# -----------------------------------------------------------------------------

resource "google_monitoring_dashboard" "frontend" {
  count   = local.create_dashboard ? 1 : 0
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "${var.component}-monitoring-dashboard"
    mosaicLayout = {
      columns = local.columns_per_row
      tiles   = local.enabled_tiles
    }
  })

  # Tile layout can drift with dashboard editor edits; ignore JSON churn
  # once created so manual UI tweaks aren't clobbered.
  lifecycle {
    ignore_changes = [dashboard_json]
  }
}
