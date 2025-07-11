variable "ecr_repository" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "app_port" {
  type = number
}
