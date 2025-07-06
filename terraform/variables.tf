variable "app_name" {
  default = "flask-aws-terraform"
}

variable "container_port" {
  default = 5000
}

variable "desired_count" {
  default = 1
}

variable "aws_account_id" {
  description = "AWS Account ID"
}
