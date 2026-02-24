## Resources for API Gateway Lambda Authorization
resource "aws_lambda_function" "authorizer" {
  function_name    = "${var.app_name}-authorizer"
  description      = "Lambda Authorizer for ${var.app_name}"
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  runtime          = var.lambda_runtime
  memory_size      = 1024
  timeout          = 900
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = local.lambda_variables
  }
  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-authorizer" }))

  tracing_config {
    mode = var.lambda_trace_mode
  }

  lifecycle {
    ignore_changes = [
      description,
      filename,
      source_code_hash,
      layers
    ]
  }
  depends_on = [
    aws_iam_role_policy.lambda_role_policy,
    aws_iam_role.lambda_role
  ]

}
