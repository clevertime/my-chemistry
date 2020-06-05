variable "prefix" {}
variable "description" {
  default = ""
}

# define api functions
variable "api_methods" {
  type = map(object({
    lambda        = string
    method        = string
    authorization = string
  }))
}
