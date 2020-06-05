provider "aws" {
  profile = var.profile
  region  = var.region
}

provider "aws" {
  alias   = "east"
  profile = var.profile
  region  = "us-east-1"
}
