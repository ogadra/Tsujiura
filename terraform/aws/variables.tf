variable "domain_name" {
  description = "FQDN for the service"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile name for the target account"
  type        = string
}

variable "budget_limit_usd" {
  description = "Monthly budget for log and DNS query costs in USD"
  type        = string
}

variable "budget_notification_emails" {
  description = "Email addresses notified when the budget threshold is exceeded"
  type        = list(string)
}
