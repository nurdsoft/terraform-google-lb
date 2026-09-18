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
