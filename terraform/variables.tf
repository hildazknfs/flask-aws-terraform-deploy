variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "aws_account_id" {
  type = string
}

variable "ecr_repository" {
  type    = string
  default = "flask-ecs-fargate-repo"
}

variable "image_tag" {
  type    = string
  default = ""
}
