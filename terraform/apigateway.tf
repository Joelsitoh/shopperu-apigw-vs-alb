# Opcion A: API Gateway (HTTP API) -> Lambda de catalogo

resource "aws_iam_role" "lambda" {
  name = "${var.prefijo}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_cloudwatch_log_group" "catalogo" {
  name              = "/aws/lambda/${var.prefijo}-catalogo"
  retention_in_days = 1
}

resource "aws_iam_role_policy" "lambda_logs" {
  name = "${var.prefijo}-lambda-logs"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.catalogo.arn}:*"
    }]
  })
}

data "archive_file" "catalogo" {
  type        = "zip"
  source_dir  = "${path.module}/src/catalogo"
  output_path = "${path.module}/build/catalogo.zip"
}

resource "aws_lambda_function" "catalogo" {
  function_name    = "${var.prefijo}-catalogo"
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  memory_size      = 256
  filename         = data.archive_file.catalogo.output_path
  source_code_hash = data.archive_file.catalogo.output_base64sha256

  depends_on = [aws_cloudwatch_log_group.catalogo, aws_iam_role_policy.lambda_logs]
}

resource "aws_apigatewayv2_api" "api" {
  name          = "${var.prefijo}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "catalogo" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.catalogo.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "productos" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /productos"
  target    = "integrations/${aws_apigatewayv2_integration.catalogo.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  # Limite de peticiones por segundo para proteger el backend en campanas
  default_route_settings {
    throttling_rate_limit  = 500
    throttling_burst_limit = 1000
  }
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.catalogo.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
