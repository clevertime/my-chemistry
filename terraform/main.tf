
# get any data required
data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

# locals
locals {
  account_id = data.aws_caller_identity.this.account_id
  region     = data.aws_region.this.name
}

##################
# frontend
##################

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

resource "aws_cloudfront_origin_access_identity" "this" {}

resource "aws_cloudfront_distribution" "frontend" {

  origin {
    domain_name = aws_s3_bucket.web.bucket_regional_domain_name
    origin_id   = var.frontend_domain_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = [var.frontend_domain_name]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.frontend_domain_name

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.frontend.arn
    ssl_support_method  = "sni-only"
  }
}

# configure cloudfront access to s3
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = [join("", [aws_s3_bucket.web.arn, "/*"])]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.this.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.web.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.this.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.web.id
  policy = data.aws_iam_policy_document.s3_policy.json
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

# dns & certs
resource "aws_route53_record" "frontend_alias" {
  zone_id = var.zone_id
  name    = var.frontend_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "frontend" {
  provider          = aws.east
  domain_name       = var.frontend_domain_name
  validation_method = "DNS"
}

resource "aws_route53_record" "frontend_record_validation" {
  name    = aws_acm_certificate.frontend.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.frontend.domain_validation_options.0.resource_record_type
  zone_id = var.zone_id
  records = [aws_acm_certificate.frontend.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "frontend" {
  provider                = aws.east
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [aws_route53_record.frontend_record_validation.fqdn]
}


##################
# backend
##################

# dynamo
resource "aws_dynamodb_table" "this" {
  for_each       = toset(var.api_resources)
  name           = join("-", [var.prefix, each.key])
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 1
  hash_key       = "timestamp"

  attribute {
    name = "timestamp"
    type = "N"
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = join("-", [var.prefix, each.key])
  }
}

data "archive_file" "lambda" {
  for_each    = var.api_functions
  type        = "zip"
  source_dir  = "${path.module}/api/${join("-", [var.prefix, each.key])}/"
  output_path = "${path.module}/api/${join("-", [var.prefix, each.key])}.zip"
}

module "lambdas" {
  for_each              = var.api_functions
  source                = "./modules/lambda"
  role_arn              = aws_iam_role.lambda.arn
  function_name         = join("-", [var.prefix, each.key])
  memory                = each.value.memory
  timeout               = each.value.timeout
  filename              = data.archive_file.lambda[each.key].output_path
  source_code_hash      = data.archive_file.lambda[each.key].output_base64sha256
  handler               = join(".", [join("-", [var.prefix, each.key]), each.value.handler])
  environment_variables = { "TABLE_NAME" = aws_dynamodb_table.this[each.value.api_resource].name }
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
# would like to make this dynamic
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
            "Resource": "${aws_dynamodb_table.this[var.api_resources[0]].arn}"
        },
        {
            "Effect": "Allow",
            "Action": "dynamodb:*",
            "Resource": "${aws_dynamodb_table.this[var.api_resources[1]].arn}"
        }
    ]
}
EOF
}

module "api-gateway" {
  source          = "./modules/api-gateway"
  prefix          = var.prefix
  resource_names  = var.api_resources
  environment     = var.environment
  domain_name     = var.api_domain_name
  certificate_arn = aws_acm_certificate.api.arn
  zone_id         = var.zone_id

  api_methods = {
    intake_post = {
      lambda        = module.lambdas["intake_post"].function_arn
      method        = "POST"
      authorization = "NONE"
      api_resource  = "intake"
    },
    intake_get = {
      lambda        = module.lambdas["intake_get"].function_arn
      method        = "GET"
      authorization = "NONE"
      api_resource  = "intake"
    },
    report_post = {
      lambda        = module.lambdas["report_post"].function_arn
      method        = "POST"
      authorization = "NONE"
      api_resource  = "report"
    },
    report_get = {
      lambda        = module.lambdas["report_get"].function_arn
      method        = "GET"
      authorization = "NONE"
      api_resource  = "report"
    }
  }
}

# dns & certs
resource "aws_acm_certificate" "api" {
  provider          = aws.east
  domain_name       = var.api_domain_name
  validation_method = "DNS"
}

resource "aws_route53_record" "api_record_validation" {
  name    = aws_acm_certificate.api.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.api.domain_validation_options.0.resource_record_type
  zone_id = var.zone_id
  records = [aws_acm_certificate.api.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "api" {
  provider                = aws.east
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [aws_route53_record.api_record_validation.fqdn]
}
