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
