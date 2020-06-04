variable "profile" {
  description = "aws profile to use"
}

variable "region" {
  description = "aws region"
  default     = "us-west-2"
}

variable "prefix" {
  description = "prefix for naming resources"
  default     = "my-chemistry"
}

variable "zone_id" {
  description = "route 53 zone id"
}
