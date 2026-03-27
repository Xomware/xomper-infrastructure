# =============================================================================
# API Lambda Functions for CRUD operations on DynamoDB tables
# These are stub definitions -- actual code is deployed from the backend repo.
# =============================================================================

locals {
  api_lambdas = [
    # Profiles
    { name = "profiles-get", description = "Get profile by ID", path_part = "{id}", http_method = "GET" },
    { name = "profiles-list", description = "List all profiles", path_part = "list", http_method = "GET" },
    { name = "profiles-create", description = "Create a profile", path_part = "create", http_method = "POST" },
    { name = "profiles-update", description = "Update a profile", path_part = "{id}", http_method = "PUT" },
    { name = "profiles-delete", description = "Delete a profile", path_part = "{id}", http_method = "DELETE" },

    # Whitelisted Users
    { name = "users-get", description = "Get whitelisted user", path_part = "{email}", http_method = "GET" },
    { name = "users-list", description = "List whitelisted users", path_part = "list", http_method = "GET" },
    { name = "users-create", description = "Add whitelisted user", path_part = "create", http_method = "POST" },
    { name = "users-delete", description = "Remove whitelisted user", path_part = "{email}", http_method = "DELETE" },

    # Rule Proposals
    { name = "rules-get", description = "Get rule proposal", path_part = "{id}", http_method = "GET" },
    { name = "rules-list", description = "List rule proposals", path_part = "list", http_method = "GET" },
    { name = "rules-create", description = "Create rule proposal", path_part = "create", http_method = "POST" },
    { name = "rules-update", description = "Update rule proposal", path_part = "{id}", http_method = "PUT" },

    # Rule Votes
    { name = "votes-get", description = "Get vote for proposal", path_part = "{proposal_id}", http_method = "GET" },
    { name = "votes-create", description = "Cast a vote", path_part = "create", http_method = "POST" },
    { name = "votes-delete", description = "Remove a vote", path_part = "{proposal_id}", http_method = "DELETE" },

    # Taxi Steal Requests
    { name = "taxi-steals-get", description = "Get taxi steal request", path_part = "{league_id}", http_method = "GET" },
    { name = "taxi-steals-create", description = "Create taxi steal request", path_part = "create", http_method = "POST" },
    { name = "taxi-steals-delete", description = "Remove taxi steal request", path_part = "{league_id}", http_method = "DELETE" },

    # Draft History
    { name = "drafts-get", description = "Get draft history", path_part = "{draft_id}", http_method = "GET" },
    { name = "drafts-create", description = "Add draft pick", path_part = "create", http_method = "POST" },

    # Matchup History
    { name = "matchups-get", description = "Get matchup history", path_part = "{league_id_season_week}", http_method = "GET" },
    { name = "matchups-create", description = "Add matchup record", path_part = "create", http_method = "POST" },

    # Season Standings
    { name = "standings-get", description = "Get season standings", path_part = "{league_id}", http_method = "GET" },
    { name = "standings-create", description = "Add standings record", path_part = "create", http_method = "POST" },
    { name = "standings-update", description = "Update standings", path_part = "{league_id}", http_method = "PUT" },

    # League Champions
    { name = "champions-get", description = "Get league champions", path_part = "{league_id}", http_method = "GET" },
    { name = "champions-create", description = "Add champion record", path_part = "create", http_method = "POST" },
  ]
}

resource "aws_lambda_function" "api" {
  for_each         = { for lambda in local.api_lambdas : lambda.name => lambda }
  function_name    = "${var.app_name}-api-${each.value.name}"
  description      = each.value.description
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
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

  tags = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-api-${each.value.name}", "lambda_type" = "api" }))

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
