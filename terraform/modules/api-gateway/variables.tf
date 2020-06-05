variable "prefix" {}
variable "description" {
  default = ""
}
variable "environment" {}

# define api functions
variable "api_methods" {
  type = map(object({
    lambda        = string
    method        = string
    authorization = string
  }))
}

variable "domain_name" {
  default     = null
  description = "provide domain name for api, if applicable"
}

variable "certificate_arn" {
  default = null
}

variable "zone_id" {
  default = null
}
