###############################################################################
# /rankings/current — nightly multi-source consensus
#
# The warehouse ingest writes rankings/current/rankings.json plus a dated copy. This
# serves it. Plain JSON on S3 rather than Parquet, so no DuckDB layer and no
# extra memory: a few hundred rows read on every draft-board load.
#
# Each row carries every source's rank plus the spread between them. The spread
# is the reason several lists are pulled at all - a player ranked 107, 179 and
# 416 is a decision, and a consensus number alone hides that.
#
# No new IAM. warehouse_access in warehouse.tf already grants the shared
# lambda_role s3:GetObject on this bucket.
###############################################################################

resource "aws_lambda_function" "rankings_current" {
  function_name    = "${var.app_name}-api-rankings-current"
  description      = "Serve the nightly consensus rankings snapshot."
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [data.aws_lambda_layer_version.shared_latest.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = merge(local.lambda_variables, {
      WAREHOUSE_BUCKET = aws_s3_bucket.warehouse.id
    })
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({
    "name"        = "${var.app_name}-api-rankings-current"
    "lambda_type" = "api"
    "handler_dir" = "api_rankings_current"
  }))

  # Code is deployed from the backend repo; Terraform owns the shape only.
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

resource "aws_cloudwatch_log_group" "rankings_current" {
  name              = "/aws/lambda/${aws_lambda_function.rankings_current.function_name}"
  retention_in_days = 14
  tags              = local.standard_tags
}
