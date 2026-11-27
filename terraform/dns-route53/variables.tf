variable "backend_bucket" {
  description = "S3 bucket holding the states of terraform/aws and terraform/google-cloud, read through terraform_remote_state."
  type        = string
}
