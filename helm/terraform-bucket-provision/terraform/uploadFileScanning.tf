# ---------------------------------------------------------------------------------------------------------------------
# The following resources will only be created if the uploaded_file_scanning_enabled variable is set to true
# ---------------------------------------------------------------------------------------------------------------------

# Create GCS buckets for quarantined and clean files
resource "google_storage_bucket" "quarantine_bucket" {
  for_each = { for v in local.storage_bucket_base_names : v => v }
  name     = "quarantined-${each.value}"
  location = local.region
}

resource "google_storage_bucket" "clean_bucket" {
  for_each = { for v in local.storage_bucket_base_names : v => v }
  name     = "clean-${each.value}"
  location = local.region
}

# Create GCP service accounts for quarantined and clean GCS buckets
resource "google_service_account" "quarantined_bucket_account" {
  for_each     = { for v in local.storage_bucket_base_names : v => v }
  account_id   = "sa-quar-${each.value}"
  display_name = "${each.value} Service Account"
  depends_on   = [google_storage_bucket.quarantine_bucket]
}

resource "google_service_account" "clean_bucket_account" {
  for_each     = { for v in local.storage_bucket_base_names : v => v }
  account_id   = "sa-clean-${each.value}"
  display_name = "${each.value} Service Account"
  depends_on   = [google_storage_bucket.clean_bucket]
}
