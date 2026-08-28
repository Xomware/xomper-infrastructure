locals {
  email_lambdas = [
    {
      name        = "taxi"
      description = "Email for taxi steal event"
      path_part   = "taxi"
      http_method = "POST"
    },
    {
      name        = "rule-proposal"
      description = "New Rule Proposal"
      path_part   = "rule-proposal"
      http_method = "POST"
    },
    {
      name        = "rule-accept"
      description = "New Rule Accepted"
      path_part   = "rule-accept"
      http_method = "POST"
    },
    {
      name        = "rule-deny"
      description = "New Rule denied"
      path_part   = "rule-deny"
      http_method = "POST"
    }
  ]
}

resource "aws_lambda_function" "email" {
  for_each         = { for lambda in local.email_lambdas : lambda.name => lambda }
  function_name    = "${var.app_name}-email-${each.value.name}"
  description      = each.value.description
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [data.aws_lambda_layer_version.shared_latest.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = local.lambda_variables
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-email-${each.value.name}", "lambda_type" = "email" }))

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