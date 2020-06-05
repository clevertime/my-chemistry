
resource "aws_api_gateway_rest_api" "this" {
  name        = var.prefix
  description = var.description
}

resource "aws_api_gateway_resource" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = var.prefix
}

resource "aws_api_gateway_method" "this" {
  for_each      = var.api_methods
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = each.value.method
  authorization = each.value.authorization
}

resource "aws_api_gateway_integration" "this" {
  for_each                = var.api_methods
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this.id
  http_method             = aws_api_gateway_method.this[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${local.region}:lambda:path/${var.prefix}/functions/${each.value.lambda}/invocations"
}

resource "aws_lambda_permission" "this" {
  for_each      = var.api_methods
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${local.region}:${local.account_id}:${aws_api_gateway_rest_api.this.id}/*/${aws_api_gateway_method.this[each.key].http_method}${aws_api_gateway_resource.this.path}"
}
