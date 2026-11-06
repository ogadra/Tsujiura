# The Budget API rejects user credentials unless a quota project is set.
provider "google" {
  alias                 = "billing"
  project               = var.project_id
  billing_project       = var.project_id
  user_project_override = true
}

resource "google_project_service" "budget" {
  for_each = toset([
    "billingbudgets.googleapis.com",
    "monitoring.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

data "google_project" "current" {}

resource "google_monitoring_notification_channel" "budget" {
  for_each = var.budget_notification_emails

  display_name = "tsujiura-budget-${each.value}"
  type         = "email"

  labels = {
    email_address = each.value
  }

  depends_on = [google_project_service.budget]
}

resource "google_billing_budget" "logs_and_dns" {
  provider = google.billing

  billing_account = var.billing_account_id
  display_name    = "tsujiura-logs-and-dns"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
    # Cloud Logging and Cloud DNS.
    services = ["services/5490-F7B7-8DF6", "services/FA26-5236-B8B5"]
  }

  amount {
    specified_amount {
      units = var.budget_amount_units
    }
  }

  threshold_rules {
    threshold_percent = 0.8
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  all_updates_rule {
    monitoring_notification_channels = [for channel in google_monitoring_notification_channel.budget : channel.id]
  }

  depends_on = [google_project_service.budget]
}
