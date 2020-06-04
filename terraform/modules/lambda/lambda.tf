
resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  description      = var.description
  role             = var.role_arn
  memory_size      = var.memory
  runtime          = var.runtime
  timeout          = var.timeout
  handler          = var.handler
  filename         = var.filename
  source_code_hash = var.source_code_hash
  tags             = var.tags

  environment {
    variables = var.environment_variables
  }
}
