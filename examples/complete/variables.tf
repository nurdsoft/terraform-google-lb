variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "component" {
  description = "Name prefix applied to every resource."
  type        = string
  default     = "frontend"
}

variable "region" {
  description = "GCP region for the Serverless NEG."
  type        = string
  default     = "us-central1"
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service the NEG routes to."
  type        = string
}

variable "customer_domain" {
  description = "Public domain served by the LB."
  type        = string
}

variable "uptime_check_path" {
  description = "Path both uptime checks request."
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
