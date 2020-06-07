
resource "aws_api_gateway_rest_api" "this" {
  name        = var.prefix
  description = var.description
}

resource "aws_api_gateway_resource" "this" {
  for_each    = toset(var.resource_names)
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.key
}

resource "aws_api_gateway_method" "this" {
  for_each      = var.api_methods
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this[each.value.api_resource].id
  http_method   = each.value.method
  authorization = each.value.authorization
}

resource "aws_api_gateway_integration" "this" {
  for_each                = var.api_methods
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this[each.value.api_resource].id
  http_method             = aws_api_gateway_method.this[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${local.region}:lambda:path/2015-03-31/functions/${each.value.lambda}/invocations"
}

resource "aws_api_gateway_method_response" "response_200" {
  for_each    = var.api_methods
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this[each.value.api_resource].id
  http_method = aws_api_gateway_method.this[each.key].http_method
  status_code = "200"
}

resource "aws_api_gateway_method_settings" "this" {
  for_each    = var.api_methods
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = var.environment
  method_path = join("/", [aws_api_gateway_resource.this[each.value.api_resource].path_part, aws_api_gateway_method.this[each.key].http_method])

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_lambda_permission" "this" {
  for_each      = var.api_methods
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${local.region}:${local.account_id}:${aws_api_gateway_rest_api.this.id}/*/*"
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = var.environment
}

resource "aws_api_gateway_domain_name" "this" {
  count           = var.domain_name != null ? 1 : 0
  certificate_arn = var.certificate_arn
  domain_name     = var.domain_name
}

resource "aws_route53_record" "this" {
  count   = var.domain_name != null ? 1 : 0
  name    = aws_api_gateway_domain_name.this[0].domain_name
  type    = "A"
  zone_id = var.zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.this[0].cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.this[0].cloudfront_zone_id
  }
}

resource "aws_api_gateway_base_path_mapping" "this" {
  count       = var.domain_name != null ? 1 : 0
  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_deployment.this.stage_name
  domain_name = aws_api_gateway_domain_name.this[0].domain_name
}
