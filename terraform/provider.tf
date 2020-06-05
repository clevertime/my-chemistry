provider "aws" {
  profile = var.profile
  region  = var.region
}

provider "aws" {
  alias   = "us-east"
  profile = var.profile
  region  = "us-east-1"
}
