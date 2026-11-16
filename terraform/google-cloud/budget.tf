# The Budget API rejects user credentials unless a quota project is set.
provider "google" {
  alias                 = "billing"
  project               = data.google_project.current.project_id
  billing_project       = data.google_project.current.project_id
  user_project_override = true
}

resource "google_project_service" "billingbudgets" {
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

resource "google_billing_budget" "main" {
  provider = google.billing

  billing_account = data.google_project.current.billing_account
  display_name    = "tsujiura"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  amount {
    specified_amount {
      currency_code = "JPY"
      units         = "5000"
    }
  }

  threshold_rules {
    threshold_percent = 0.8
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  depends_on = [google_project_service.billingbudgets]
}
