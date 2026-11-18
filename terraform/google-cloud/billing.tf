resource "google_project_service" "billingbudgets" {
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = true
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
