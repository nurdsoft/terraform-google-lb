# terraform-google-external-https-lb

A Terraform module for provisioning a GCP external HTTPS load balancer in front of a single Cloud Run service — reserved static IP, Serverless NEG, backend service, HTTP→HTTPS redirect, Google-managed SSL certificate, HTTPS forwarding rule, plus optional uptime checks and a monitoring dashboard bundled behind feature flags.

## Features

- Reserved external IPv4 (`google_compute_global_address`)
- Serverless NEG → Cloud Run (`google_compute_region_network_endpoint_group`, region-scoped)
- Backend service (`google_compute_backend_service`) with optional Cloud Armor attachment; request logging auto-enabled when a security policy is attached (required for Cloud Armor verdicts in Cloud Logging)
- Main URL map + HTTP→HTTPS redirect URL map + HTTP proxy + port-80 forwarding rule (always created)
- Google-managed SSL certificate + HTTPS target proxy + port-443 forwarding rule (created when `customer_domain` is set)
- Two uptime checks — HTTPS on port 443 and HTTP-redirect check on port 80 — bundled behind `enable_uptime_check` (default `true`; require `customer_domain`)
- Monitoring dashboard with response-time, request-count, 4xx/5xx error, and uptime tiles behind `enable_dashboard` (default `true`; requires `customer_domain`); tile layout and metric filters are auto-scoped to the module's own URL map + `customer_domain`

## Assumptions

- A basic understanding of [Git](https://git-scm.com/).
- Git version `>= 2.33.0`.
- An existing GCP IAM user or service account with permissions to create/update/delete the resources defined in [main.tf](https://github.com/nurdsoft/terraform-google-external-https-lb/blob/main/main.tf).
- [GCloud CLI](https://cloud.google.com/sdk/docs/install) `>= 465.0.0`.
- A basic understanding of [Terraform](https://www.terraform.io/).
- Terraform version `>= 1.3.0`.
- (Optional — for local testing) A basic understanding of [Make](https://www.gnu.org/software/make/manual/make.html#Introduction).
  - Make version `>= GNU Make 3.81`.
  - **Important Note**: This project includes a [Makefile](https://github.com/nurdsoft/terraform-google-external-https-lb/blob/main/Makefile) to speed up local development in Terraform. The `make` targets act as a wrapper around Terraform commands. As such, `make` has only been tested/verified on **Linux/Mac OS**. Though, it is possible to [install make using Chocolatey](https://community.chocolatey.org/packages/make), we **do not** guarantee this approach as it has not been tested/verified. You may use the commands in the [Makefile](https://github.com/nurdsoft/terraform-google-external-https-lb/blob/main/Makefile) as a guide to run each Terraform command locally on Windows.

---

## Test

**Important Note**: This project includes a [Makefile](https://github.com/nurdsoft/terraform-google-external-https-lb/blob/main/Makefile) to speed up local development in Terraform. The `make` targets act as a wrapper around Terraform commands. As such, `make` has only been tested/verified on **Linux/Mac OS**. Though, it is possible to [install make using Chocolatey](https://community.chocolatey.org/packages/make), we **do not** guarantee this approach as it has not been tested/verified. You may use the commands in the [Makefile](https://github.com/nurdsoft/terraform-google-external-https-lb/blob/main/Makefile) as a guide to run each Terraform command locally on Windows.

```sh
gcloud init # https://cloud.google.com/docs/authentication/gcloud
gcloud auth application-default login

# Copy the example tfvars and customize it
cp examples/complete/examples.tfvars examples/complete/terraform.tfvars
# Edit terraform.tfvars with your values

# Run terraform commands
make plan
make apply
make destroy
```

---

## Contributions

Contributions are always welcome. As such, this project uses the `main` branch as the source of truth to track changes.

**Step 1**. Clone this project.

```sh
# Using SSH
$ git clone git@github.com:nurdsoft/terraform-google-external-https-lb.git

# Using HTTPS
$ git clone https://github.com/nurdsoft/terraform-google-external-https-lb.git
```

**Step 2**. Checkout a feature branch: `git checkout -b feat/abc`.

**Step 3**. Validate the change/s locally by executing the steps defined under [Test](#test).

**Step 4**. If testing is successful, commit and push the new change/s to the remote.

```sh
$ git add file1 file2 ...

$ git commit -m "Adding some change"

$ git push --set-upstream origin feat/abc
```

**Step 5**. Once pushed, create a [PR](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request) and assign it to a member for review.

- **Important Note**: It can be helpful to attach the `terraform plan` output in the PR.

**Step 6**. A team member reviews/approves/merges the change/s.

**Step 7**. Once merged, deploy the required changes as needed.

- If possible, please add a `plan` output using the feature branch so the member reviewing the PR has better visibility into the changes.

---

## Usage

```hcl
module "external_https_lb" {
  source  = "nurdsoft/external-https-lb/google"
  version = "1.0.0"

  project_id             = "my-gcp-project"
  component              = "frontend"
  region                 = "us-central1"
  cloud_run_service_name = "my-frontend-service"

  customer_domain = "app.example.com"
}
```

### With Cloud Armor attached

```hcl
module "cloud_armor" {
  source  = "nurdsoft/cloud-armor/google"
  version = "1.0.0"

  project_id = "my-gcp-project"
  name       = "frontend-armor-policy"
}

module "external_https_lb" {
  source  = "nurdsoft/external-https-lb/google"
  version = "1.0.0"

  project_id             = "my-gcp-project"
  component              = "frontend"
  region                 = "us-central1"
  cloud_run_service_name = "my-frontend-service"
  customer_domain        = "app.example.com"

  security_policy_self_link = module.cloud_armor.self_link
}
```

### HTTP-only (no domain yet)

Provisions the static IP + backend + HTTP redirect only. Useful for reserving the IP before DNS is ready.

```hcl
module "external_https_lb" {
  source  = "nurdsoft/external-https-lb/google"
  version = "1.0.0"

  project_id             = "my-gcp-project"
  component              = "frontend"
  region                 = "us-central1"
  cloud_run_service_name = "my-frontend-service"

  # customer_domain omitted → HTTPS, uptime checks, dashboard all skipped
}
```

### What's always vs conditionally created

| Resource                                             | Created                                                            |
|------------------------------------------------------|--------------------------------------------------------------------|
| `google_compute_global_address.static_ip`            | Always                                                             |
| `google_compute_region_network_endpoint_group.cloudrun_neg` | Always                                                      |
| `google_compute_backend_service.cloudrun_backend`    | Always (log_config enabled iff `security_policy_self_link != null`) |
| `google_compute_url_map.main`                        | Always                                                             |
| `google_compute_url_map.https_redirect`              | Always                                                             |
| `google_compute_target_http_proxy.http_proxy`        | Always                                                             |
| `google_compute_global_forwarding_rule.http`         | Always                                                             |
| `google_compute_managed_ssl_certificate.ssl_cert`    | `customer_domain != ""`                                            |
| `google_compute_target_https_proxy.https_proxy`      | `customer_domain != ""`                                            |
| `google_compute_global_forwarding_rule.https`        | `customer_domain != ""`                                            |
| `google_monitoring_uptime_check_config.https`        | `enable_uptime_check && customer_domain != ""`                     |
| `google_monitoring_uptime_check_config.http_redirect`| `enable_uptime_check && customer_domain != ""`                     |
| `google_monitoring_dashboard.frontend`               | `enable_dashboard && customer_domain != ""`                        |

## Examples

| Example | Description |
|---|---|
| [minimal](./examples/minimal) | HTTP-only stack: static IP + NEG + backend + main URL map + HTTP redirect. HTTPS, uptime, dashboard all skipped. |
| [complete](./examples/complete) | Full setup: HTTPS + uptime checks + dashboard + Cloud Armor attached. |

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| google | ~> 5.0 |

## Providers

| Name | Version |
|---|---|
| [google](https://registry.terraform.io/providers/hashicorp/google/latest) | ~> 5.0 |

## Inputs

### Required

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `project_id` | GCP project ID that owns the LB stack. | `string` | n/a | yes |
| `component` | Name prefix applied to every resource. | `string` | n/a | yes |
| `region` | GCP region for the Serverless NEG. Must match the target Cloud Run region. | `string` | n/a | yes |
| `cloud_run_service_name` | Name of the Cloud Run service the NEG routes to. Service lifecycle is expected to be managed outside this module. | `string` | n/a | yes |

### Optional

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `customer_domain` | Public domain served by the LB. Empty → HTTPS/uptime/dashboard all skipped. | `string` | `""` | no |
| `ssl_domains` | Domains on the managed SSL cert. Null → `[customer_domain, "www.<customer_domain>"]`. | `list(string)` | `null` | no |
| `ssl_cert_name_suffix` | Suffix for SSL cert name: `<component>-<suffix>`. | `string` | `"cdn-ssl-cert-v2"` | no |
| `security_policy_self_link` | Cloud Armor policy to attach to the backend service. When set, backend request logging is enabled. | `string` | `null` | no |
| `enable_uptime_check` | Create HTTPS + HTTP-redirect uptime checks. Requires `customer_domain`. | `bool` | `true` | no |
| `uptime_check_path` | Path both uptime checks request. | `string` | `"/"` | no |
| `uptime_check_period` | Uptime check frequency in seconds. | `number` | `300` | no |
| `uptime_check_timeout` | Uptime check per-request timeout in seconds. | `number` | `10` | no |
| `enable_dashboard` | Create the monitoring dashboard. Requires `customer_domain`. | `bool` | `true` | no |
| `dashboard_tiles` | Dashboard tile definitions. See [variables.tf](./variables.tf) for the object schema and default 5-tile set. | `list(object)` | 5-tile default | no |

## Outputs

| Name | Description |
|---|---|
| `static_ip_address` | Reserved external IPv4. Point the customer domain's A record here. |
| `static_ip_name` | Name of the reserved global address resource. |
| `backend_service_id` | ID of the backend service. |
| `backend_service_name` | Name of the backend service. |
| `url_map_name` | Name of the main URL map. Use in log-sink filters and alert-policy metric filters. |
| `url_map_id` | ID of the main URL map. |
| `https_redirect_url_map_id` | ID of the HTTP→HTTPS redirect URL map. |
| `ssl_certificate_id` | ID of the managed SSL cert. Null when `customer_domain` is empty. |
| `dashboard_id` | ID of the monitoring dashboard. Null when disabled. |
| `https_uptime_check_id` | ID of the HTTPS uptime check. Null when disabled. |
| `http_redirect_uptime_check_id` | ID of the HTTP redirect uptime check. Null when disabled. |

## Authors

Module is maintained by [Nurdsoft](https://github.com/nurdsoft).

## License

Apache 2 Licensed. See [LICENSE](https://github.com/nurdsoft/terraform-google-external-https-lb/blob/main/LICENSE) for full details.
