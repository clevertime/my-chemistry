# get any data required
data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

# locals
locals {
  account_id = data.aws_caller_identity.this.account_id
  region     = data.aws_region.this.name
}
