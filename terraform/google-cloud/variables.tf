variable "domain_name" {
  description = "FQDN for the service"
  type        = string
}

variable "project_id" {
  description = "Google Cloud project ID dedicated to Tsujiura"
  type        = string
}

variable "billing_account_id" {
  description = "Cloud Billing account ID that owns the budget"
  type        = string
}

variable "budget_amount_units" {
  description = "Monthly budget for log and DNS query costs in whole units of the billing account currency"
  type        = string
}

variable "budget_notification_emails" {
  description = "Email addresses notified when the budget threshold is exceeded"
  type        = set(string)
}
