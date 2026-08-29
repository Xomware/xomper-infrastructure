###############################################################################
# /adp/current — nightly Fantasy Football Calculator snapshot
#
# The warehouse ingest writes adp/current/adp.json plus a dated copy. This
# serves it. Plain JSON on S3 rather than Parquet, so no DuckDB layer and no
# extra memory: the payload is a few thousand small rows read on every
# draft-board load.
#
# No new IAM. warehouse_access in warehouse.tf already grants the shared
# lambda_role s3:GetObject on this bucket.
###############################################################################

resource "aws_lambda_function" "adp_current" {
  function_name    = "${var.app_name}-api-adp-current"
  description      = "Serve the nightly ADP snapshot from the warehouse."
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
    "name"        = "${var.app_name}-api-adp-current"
    "lambda_type" = "api"
    "handler_dir" = "api_adp_current"
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

resource "aws_cloudwatch_log_group" "adp_current" {
  name              = "/aws/lambda/${aws_lambda_function.adp_current.function_name}"
  retention_in_days = 14
  tags              = local.standard_tags
}
