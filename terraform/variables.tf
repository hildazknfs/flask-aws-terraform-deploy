variable "app_name" {
  description = "Name of the application and ECR repo"
}

variable "container_port" {
  default = 5000
}

variable "desired_count" {
  default = 1
}

variable "aws_account_id" {}

variable "aws_region" {}

variable "image_tag" {
  default = "latest"
}
