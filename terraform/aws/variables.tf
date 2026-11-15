variable "budget_limit_usd" {
  description = "Monthly budget for resources tagged Project = Tsujiura in USD"
  type        = string
}

variable "budget_notification_emails" {
  description = "Email addresses notified when the budget threshold is exceeded"
  type        = list(string)
}
