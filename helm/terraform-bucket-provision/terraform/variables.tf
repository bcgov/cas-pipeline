# Since variables could be overridden via environment variables, use local values to define immutable values
locals {
  # The GCP region to create things in. https://cloud.google.com/compute/docs/regions-zones"
  region = "northamerica-northeast1" # Montreal

  # An array of storage bucket names to be used for uploaded files
  storage_bucket_base_names = [for v in var.apps : "${var.openshift_namespace}-${v}"]
}

variable "project_id" {
  description = "The ID of the GCP project"
}

variable "kubernetes_host" {
  description = "The hostname of the OCP cluster"
}

variable "kubernetes_token" {
  description = "The authentication token of the OCP cluster"
}

variable "apps" {
  type        = list(string)
  description = "The list of app names for the OCP project in a namespace"
}

variable "openshift_namespace" {
  type        = string
  description = "The OCP project namespace"
}

variable "iam_storage_role_template_id" {
  type        = string
  description = "ID for a custom IAM role template we manually created in GCP for Storage Viewers"
  default     = "casStorageViewer"
}

variable "uploaded_file_scanning_enabled" {
  type        = bool
  description = "Enables uploaded file scanning in GCP using ClamAV"
  default     = false
}
