# meta
variable "tags" {
  type        = map(string)
  description = "Map of tags to put on the resource"
  default     = {}
}

# lambda
variable "runtime" {
  description = "Runtime version Lambda function"
  default     = "python3.8"
}

variable "role_arn" {}

variable "timeout" {
  description = "Timeout value for Lambda function"
  default     = 60
}

variable "memory" {
  description = "Timeout value for Lambda function"
  default     = 256
}

variable "function_name" {
  description = "Function Name"
}

variable "description" {
  default = ""
}

variable "handler" {
  description = "$FUNCTION_NAME.$FUNCTION_HANDLER"
}

variable "filename" {}

variable "source_code_hash" {}

variable "environment_variables" {
  type = map
}
