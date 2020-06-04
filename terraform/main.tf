
# get any data required
data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

# locals
locals {
  account_id = data.aws_caller_identity.this.account_id
  region     = data.aws_region.this.name
}

# s3 bucket
resource "aws_s3_bucket" "web" {
  bucket_prefix = join("-", [var.prefix, "web-"])
  acl           = "public-read"

  website {
    index_document = "index.html"
  }

  versioning {
    enabled = true
  }
}

# Upload Static Files to s3
resource "null_resource" "cluster" {

  provisioner "local-exec" {
    # Bootstrap script called with private_ip of each node in the clutser
    command = "aws s3 sync ../web/ s3://${aws_s3_bucket.web.id} --profile ${var.profile}"
  }

  depends_on = [
    aws_s3_bucket.web
  ]
}

# route53
resource "aws_route53_record" "naked" {
  zone_id = var.zone_id
  name    = var.prefix
  type    = "CNAME"
  ttl     = "300"
  records = [aws_s3_bucket.web.bucket_domain_name]
}

resource "aws_route53_record" "www" {
  zone_id = var.zone_id
  name    = join(".", ["www", var.prefix])
  type    = "CNAME"
  ttl     = "300"
  records = [aws_s3_bucket.web.bucket_domain_name]
}

# dynamo
resource "aws_dynamodb_table" "records" {
  name           = join("-", [var.prefix, "records"])
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 1
  hash_key       = "timestamp"

  attribute {
    name = "timestamp"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = join("-", [var.prefix, "records"])
  }
}



###############
# api
###############

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/api/${join("-", [var.prefix, "post"])}/"
  output_path = "${path.module}/api/${join("-", [var.prefix, "post"])}.zip"
}

module "post_lambda" {
  source           = "./modules/lambda"
  role_arn         = aws_iam_role.lambda.arn
  function_name    = join("-", [var.prefix, "post"])
  memory           = 256
  timeout          = 60
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = join(".", [join("-", [var.prefix, "post"]), "handler"])
}

# lambda iam role
resource "aws_iam_role" "lambda" {
  name               = join("-", [var.prefix, "lambda"])
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# lambda iam policy
resource "aws_iam_role_policy" "lambda" {
  name   = join("-", [var.prefix, "lambda"])
  role   = aws_iam_role.lambda.name
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "dynamodb:*",
            "Resource": "${aws_dynamodb_table.records.arn}"
        }
    ]
}
EOF
}
