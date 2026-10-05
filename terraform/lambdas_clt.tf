###############################################################################
# /clt/* — CLT Dynasty's own features on the Xomper API
#
# CLT (clt.dynasty.xomware.com) calls this API with clt-client tokens. The
# authorizer gives those tokens a fixed route list that includes */clt/*.
# Every handler calls clt_gate.require_member first, so a Xomper user who is
# not on CLT's roster gets 403 here.
#
# One Lambda per feature, several routes each. Routes are flat because the API
# module takes only path_prefix + path_part. Backend dirs:
#   lambdas/api_clt_<feature>/ -> xomper-api-clt-<feature>
#
# No new IAM: the shared lambda_role's table/xomper* grant covers the reused
# CLT tables and xomper-clt-settings.
###############################################################################

locals {
  clt_lambdas = {
    me        = "CLT: caller's member row and linked Sleeper id"
    proposals = "CLT: rule proposals and votes"
    taxi      = "CLT: taxi squad steal requests"
    members   = "CLT: admin roster management"
    settings  = "CLT: league settings (email notifications)"
    worldcup  = "CLT: World Cup standings across the league chain"
  }

  clt_routes = [
    { name = "clt-me", lambda = "me", path_part = "me", http_method = "GET" },
    { name = "clt-proposals-list", lambda = "proposals", path_part = "proposals-list", http_method = "GET" },
    { name = "clt-proposals-create", lambda = "proposals", path_part = "proposals-create", http_method = "POST" },
    { name = "clt-proposals-vote", lambda = "proposals", path_part = "proposals-vote", http_method = "POST" },
    { name = "clt-proposals-delete", lambda = "proposals", path_part = "proposals-delete", http_method = "POST" },
    { name = "clt-proposals-status", lambda = "proposals", path_part = "proposals-status", http_method = "POST" },
    { name = "clt-taxi-list", lambda = "taxi", path_part = "taxi-list", http_method = "GET" },
    { name = "clt-taxi-request", lambda = "taxi", path_part = "taxi-request", http_method = "POST" },
    { name = "clt-members-list", lambda = "members", path_part = "members-list", http_method = "GET" },
    { name = "clt-members-update", lambda = "members", path_part = "members-update", http_method = "POST" },
    { name = "clt-settings", lambda = "settings", path_part = "settings", http_method = "GET" },
    { name = "clt-settings-update", lambda = "settings", path_part = "settings-update", http_method = "POST" },
    { name = "clt-world-cup", lambda = "worldcup", path_part = "world-cup", http_method = "GET" },
  ]

  clt_endpoints = [
    for r in local.clt_routes : {
      name        = r.name
      path_part   = r.path_part
      http_method = r.http_method
      invoke_arn  = aws_lambda_function.clt[r.lambda].invoke_arn
    }
  ]
}

resource "aws_lambda_function" "clt" {
  for_each         = local.clt_lambdas
  function_name    = "${var.app_name}-api-clt-${each.key}"
  description      = each.value
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

  tags = merge(local.standard_tags, tomap({
    "name"        = "${var.app_name}-api-clt-${each.key}"
    "lambda_type" = "api"
    "handler_dir" = "api_clt_${each.key}"
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

resource "aws_cloudwatch_log_group" "clt" {
  for_each          = aws_lambda_function.clt
  name              = "/aws/lambda/${each.value.function_name}"
  retention_in_days = 14
  tags              = local.standard_tags
}
