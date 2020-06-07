variable "profile" {
  description = "aws profile to use"
}


variable "region" {
  description = "aws region"
  default     = "us-west-2"
}

variable "environment" {}

variable "prefix" {
  description = "prefix for naming resources"
  default     = "my-chemistry"
}

variable "zone_id" {
  description = "route 53 zone id"
}

variable "api_resources" {
  type = list
}
# define api functions
variable "api_functions" {
  type = map(object({
    memory       = number
    timeout      = number
    handler      = string
    api_resource = string
  }))
}

variable "api_domain_name" {
  default = null
}
