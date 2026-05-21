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

    # Device Registration (Push Notifications)
    { name = "device-register", description = "Register device for push notifications", path_part = "register", http_method = "POST" },
    { name = "device-unregister", description = "Unregister device from push notifications", path_part = "unregister", http_method = "POST" },

    # Admin Portal (notification activity log + test send)
    # Backend dirs:
    #   lambdas/api_admin_list_notifications/             → xomper-api-admin-list-notifications
    #   lambdas/api_admin_test_send/                      → xomper-api-admin-test-send
    #   lambdas/api_admin_ai_review_postdraft_trigger/    → xomper-api-admin-ai-review-postdraft-trigger
    { name = "admin-list-notifications", description = "Admin: list recent push + email activity", path_part = "notifications", http_method = "GET" },
    { name = "admin-test-send", description = "Admin: fire a sample push + email back to caller", path_part = "test-send", http_method = "POST" },

    # AI Review (F1) — admin-triggered post-draft report generator.
    # The api-gateway-service v2.2.0 module supports only `path_prefix` + `path_part`
    # (two-segment paths). Per the F1 plan's Step 3 fallback, the route is flattened
    # under the existing `admin` service block as `/admin/ai-review-postdraft-trigger`
    # instead of the deeper `/admin/ai-review/post-draft/trigger`. JWT + admin gate
    # are enforced by the shared authorizer (lambdas/authorizer/) and the backend
    # handler (mirrors api_admin_test_send admin check).
    { name = "admin-ai-review-postdraft-trigger", description = "Admin: trigger post-draft AI review generation (body: dry_run, force)", path_part = "ai-review-postdraft-trigger", http_method = "POST" },

    # AI Review (F2) — admin-triggered preseason report generator.
    # Same wiring + auth model as F1's post-draft trigger above. Path is flattened
    # under `/admin/*` for the same api-gateway-service v2.2.0 reason. Backend dir:
    #   lambdas/api_admin_ai_review_preseason_trigger/  → xomper-api-admin-ai-review-preseason-trigger
    # IAM coverage: existing wildcards on xomper-lambda-exec (Dynamo R/W, SSM read,
    # SES, SNS) already cover the new lambda — no IAM changes needed.
    { name = "admin-ai-review-preseason-trigger", description = "AI Review: admin-triggered preseason report (dry-run first, then broadcast)", path_part = "ai-review-preseason-trigger", http_method = "POST" },

    # AI Review (F3) — admin-triggered weekly recap (cron retries + dry-run calibration).
    # Same wiring + auth model as F1/F2 above. Flattened under `/admin/*` for the
    # same api-gateway-service v2.2.0 reason. Backend dir:
    #   lambdas/api_admin_ai_review_weekly_trigger/  → xomper-api-admin-ai-review-weekly-trigger
    # IAM coverage: existing wildcards on xomper-lambda-exec already cover the new
    # lambda + xomper-ai-memories R/W — no IAM changes needed.
    { name = "admin-ai-review-weekly-trigger", description = "AI Review: weekly recap admin trigger (cron retries + dry-run calibration)", path_part = "ai-review-weekly-trigger", http_method = "POST" },

    # AI Review (F0) — paginated archive + latest-by-type reads.
    # Routes land at /ai-reports/latest and /ai-reports/list under the new
    # `ai-reports` API GW service block (see api_gateway.tf). Query params
    # are documented in the backend handlers; iOS hits both via XomperAPIClient.
    # Backend dirs:
    #   lambdas/api_ai_reports_latest/  → xomper-api-ai-reports-latest
    #   lambdas/api_ai_reports_list/    → xomper-api-ai-reports-list
    { name = "ai-reports-latest", description = "AI Review: latest report by type (query ?type=postDraft|preseason|weekly)", path_part = "latest", http_method = "GET" },
    { name = "ai-reports-list", description = "AI Review: paginated archive (query ?type=&limit=&cursor=)", path_part = "list", http_method = "GET" },
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
