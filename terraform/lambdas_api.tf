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

    # Admin Portal (F1) — test email sender + recipients picker.
    # Lets an admin re-send any of the latest AI Review reports to a single
    # whitelisted user without polluting broadcast state. Same JWT + admin gate
    # as the other /admin/* routes (shared authorizer + handler-level
    # require_admin). Backend dirs:
    #   lambdas/api_admin_email_test/             → xomper-api-admin-email-test
    #   lambdas/api_admin_email_test_recipients/  → xomper-api-admin-email-test-recipients
    # IAM coverage: existing wildcards on xomper-lambda-exec (Dynamo R/W, SSM
    # read, SES, Supabase via env) already cover both lambdas — no IAM changes.
    { name = "admin-email-test", description = "Admin: send a single AI Review report to one whitelisted user", path_part = "email-test", http_method = "POST" },
    { name = "admin-email-test-recipients", description = "Admin: list whitelisted users for the test-email picker", path_part = "email-test-recipients", http_method = "GET" },
    { name = "admin-email-test-template", description = "Admin: send a sample non-AI-Review email template (weekly_recap, lineup_not_set, rule_*, taxi_*) to one whitelisted user", path_part = "email-test-template", http_method = "POST" },

    # Admin Portal (F3) — toggle is_redacted / do_not_broadcast metadata flags on
    # an AI report row. The api-gateway-service v2.2.0 module supports only
    # `path_prefix` + `path_part` (two-segment paths) so the route is flattened
    # under the existing `admin` service block as `/admin/reports-flag` (mirrors
    # the F1/F2 admin-trigger flatten pattern, e.g. ai-review-postdraft-trigger).
    # league_id / report_type / period are passed in the JSON body instead of
    # path params. Same JWT + admin gate as other /admin/* routes (shared
    # authorizer + handler-level require_admin). Backend dir:
    #   lambdas/api_admin_reports_flag/  → xomper-api-admin-reports-flag
    # IAM coverage: existing wildcards on xomper-lambda-exec (Dynamo R/W on
    # xomper-ai-reports, SSM read, Supabase via env) already cover the new
    # lambda — no IAM changes needed.
    { name = "admin-reports-flag", description = "Admin: toggle is_redacted / do_not_broadcast on an AI report row (body: league_id, report_type, period, flag, value)", path_part = "reports-flag", http_method = "POST" },

    # Admin Portal (F4) — Table Editor + Audit Log. Typed writes on the
    # whitelisted_users / whitelisted_leagues Supabase tables plus a paginated
    # audit feed read of the `admin_audit` Supabase table. Routes are flattened
    # under the existing `admin` service block per the api-gateway-service
    # v2.2.0 constraint (single segment under /admin), mirroring the F1/F3
    # flatten pattern (email-test, reports-flag). Same JWT + admin gate as
    # other /admin/* routes (shared authorizer + handler-level require_admin).
    # The `admin_audit` Supabase table is created out-of-band via a manual SQL
    # migration applied through the Supabase dashboard — no Terraform changes
    # for the table itself. Backend dirs:
    #   lambdas/api_admin_users_update/    → xomper-api-admin-users-update
    #   lambdas/api_admin_leagues_update/  → xomper-api-admin-leagues-update
    #   lambdas/api_admin_leagues_list/    → xomper-api-admin-leagues-list
    #   lambdas/api_admin_audit_list/      → xomper-api-admin-audit-list
    # IAM coverage: existing wildcards on xomper-lambda-exec (Dynamo R/W, SSM
    # read, SES, Supabase via env) already cover the new lambdas — no IAM
    # changes needed.
    { name = "admin-users-update", description = "Admin: update an allowlisted-field subset of a whitelisted_users row (body: user_id, fields)", path_part = "users-update", http_method = "POST" },
    { name = "admin-leagues-update", description = "Admin: update an allowlisted-field subset of a whitelisted_leagues row (body: league_id, fields)", path_part = "leagues-update", http_method = "POST" },
    { name = "admin-users-list", description = "Admin: list whitelisted_users (full rows incl. inactive for the Tables editor)", path_part = "users-list", http_method = "GET" },
    { name = "admin-leagues-list", description = "Admin: list whitelisted_leagues (full rows for the Tables editor)", path_part = "leagues-list", http_method = "GET" },
    { name = "admin-audit-list", description = "Admin: paginated audit feed from admin_audit (query ?limit=&cursor=&action=&actor_user_id=)", path_part = "audit-list", http_method = "GET" },

    # Admin Cron Settings — per-lambda Enabled kill switch + Test Mode flag for
    # the five scheduled notif lambdas (notif_weekly_recap, notif_lineup_not_set,
    # notif_close_game_alert, notif_worldcup_movement, notif_ai_review_weekly).
    # Backed by a new `admin_cron_settings` Supabase table (created out-of-band
    # via the Supabase dashboard — no Terraform changes for the table itself).
    # Routes flattened under the existing `admin` service block per the same
    # api-gateway-service v2.2.0 constraint as F1/F3/F4 above. Same JWT + admin
    # gate as other /admin/* routes (shared authorizer + handler-level
    # require_admin). Update writes an `admin_audit` row. Backend dirs:
    #   lambdas/api_admin_cron_settings_list/    → xomper-api-admin-cron-settings-list
    #   lambdas/api_admin_cron_settings_update/  → xomper-api-admin-cron-settings-update
    # IAM coverage: existing wildcards on xomper-lambda-exec (Dynamo R/W, SSM
    # read, SES, Supabase via env) already cover the new lambdas — no IAM
    # changes needed.
    { name = "admin-cron-settings-list", description = "Admin: list all admin_cron_settings rows (enabled + test_mode per cron)", path_part = "cron-settings-list", http_method = "GET" },
    { name = "admin-cron-settings-update", description = "Admin: patch enabled / test_mode on a single admin_cron_settings row (body: cron_key, enabled?, test_mode?)", path_part = "cron-settings-update", http_method = "POST" },

    # Admin Portal (F5) — CloudWatch Log Viewer. Reads a tail of admin-relevant
    # lambda log groups via `logs:FilterLogEvents` and returns paginated events
    # with server-side PII redaction (email / Sleeper user id / Anthropic key).
    # Route flattened under the existing `admin` service block per the same
    # api-gateway-service v2.2.0 constraint as F1/F3/F4. Same JWT + admin gate
    # as other /admin/* routes (shared authorizer + handler-level require_admin).
    # Backend dir:
    #   lambdas/api_admin_logs_query/  → xomper-api-admin-logs-query
    # IAM coverage: a dedicated explicit policy attached to the shared
    # xomper-lambda-exec role enumerates the 10 allowlisted log-group ARNs
    # (Option B from the F5 plan — see iam_admin_logs.tf). The handler also
    # enforces the same allowlist at runtime via ADMIN_LOG_GROUP_ALLOWLIST in
    # lambdas/common/constants.py so any non-allowlisted log_group query param
    # returns 400 before boto3 is hit.
    { name = "admin-logs-query", description = "Admin: tail CloudWatch log events for an allowlisted lambda log group (query ?log_group=&level=&search=&limit=&next_token=)", path_part = "logs-query", http_method = "GET" },

    # AI Review (F0) — paginated archive + latest-by-type reads.
    # Routes land at /ai-reports/latest and /ai-reports/list under the new
    # `ai-reports` API GW service block (see api_gateway.tf). Query params
    # are documented in the backend handlers; iOS hits both via XomperAPIClient.
    # Backend dirs:
    #   lambdas/api_ai_reports_latest/  → xomper-api-ai-reports-latest
    #   lambdas/api_ai_reports_list/    → xomper-api-ai-reports-list
    { name = "ai-reports-latest", description = "AI Review: latest report by type (query ?type=postDraft|preseason|weekly)", path_part = "latest", http_method = "GET" },
    { name = "ai-reports-list", description = "AI Review: paginated archive (query ?type=&limit=&cursor=)", path_part = "list", http_method = "GET" },

    # Announcements — admin-editable league announcements replacing the
    # hardcoded LeagueAnnouncements.current array shipped in Season Refocus F2.
    # One public read (JWT-gated, not admin-gated) plus four admin-gated
    # CRUD routes. Backed by a new `league_announcements` Supabase table
    # (created out-of-band via the Supabase dashboard — no Terraform changes
    # for the table itself). Public read lands at /announcements/list under
    # the new `announcements` API GW service block (see api_gateway.tf),
    # mirroring the F0 ai-reports two-segment flatten for the same
    # api-gateway-service v2.2.0 constraint (path_prefix + path_part only).
    # The four admin routes flatten under the existing `admin` service block
    # per the F1/F3/F4 admin-flatten pattern (email-test, reports-flag,
    # users-update, ...). Same JWT + admin gate as other /admin/* routes
    # (shared authorizer + handler-level require_admin). Write handlers
    # append an `admin_audit` row. Backend dirs:
    #   lambdas/api_announcements/                    → xomper-api-announcements
    #   lambdas/api_admin_announcements_list/         → xomper-api-admin-announcements-list
    #   lambdas/api_admin_announcements_create/       → xomper-api-admin-announcements-create
    #   lambdas/api_admin_announcements_update/       → xomper-api-admin-announcements-update
    #   lambdas/api_admin_announcements_delete/       → xomper-api-admin-announcements-delete
    # IAM coverage: existing wildcards on xomper-lambda-exec (Dynamo R/W,
    # SSM read, SES, Supabase via env) already cover the new lambdas — no
    # IAM changes needed.
    { name = "announcements", description = "Announcements: list active league announcements (public read, JWT-gated)", path_part = "list", http_method = "GET" },
    { name = "admin-announcements-list", description = "Admin: list all league_announcements rows (full rows incl. inactive/expired for the editor)", path_part = "announcements-list", http_method = "GET" },
    { name = "admin-announcements-create", description = "Admin: create a league_announcements row (body: title, body, priority, expires_at?, is_active?, display_order?)", path_part = "announcements-create", http_method = "POST" },
    { name = "admin-announcements-update", description = "Admin: patch an allowlisted-field subset of a league_announcements row (body: id, fields)", path_part = "announcements-update", http_method = "POST" },
    { name = "admin-announcements-delete", description = "Admin: soft-delete a league_announcements row by id (sets is_active=false; body: id)", path_part = "announcements-delete", http_method = "POST" },
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
