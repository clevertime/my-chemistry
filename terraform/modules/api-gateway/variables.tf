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
