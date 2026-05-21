###############################################################################
# Scheduled notification lambdas (EventBridge cron triggers).
#
# Pairs with xomper-back-end:lambdas/notif_*/handler.py.
# All four reuse the existing lambda IAM role + layer; no API Gateway
# integration. EventBridge fires each on its cron rule, the handler reads
# Supabase + Sleeper, and emits push (and optionally email) via the
# existing send_push_to_users / send_emails_concurrently infra.
#
# Schedules use the America/New_York timezone (EventBridge supports
# this since 2023, no manual DST handling required).
###############################################################################

locals {
  scheduled_lambdas = [
    {
      name              = "notif-weekly-recap"
      handler_dir       = "notif_weekly_recap"
      description       = "Tuesday morning: per-manager weekly matchup recap push."
      cron_expression   = "cron(0 9 ? * TUE *)" # Tue 09:00 ET
      schedule_timezone = "America/New_York"
    },
    {
      name              = "notif-lineup-not-set"
      handler_dir       = "notif_lineup_not_set"
      description       = "Sunday morning reminder: starters on bye / OUT."
      cron_expression   = "cron(0 11 ? * SUN *)" # Sun 11:00 ET
      schedule_timezone = "America/New_York"
    },
    {
      name              = "notif-close-game-sun"
      handler_dir       = "notif_close_game_alert"
      description       = "Sunday primetime close-game alert (within 10 pts)."
      cron_expression   = "cron(0 20 ? * SUN *)" # Sun 20:00 ET
      schedule_timezone = "America/New_York"
    },
    {
      name              = "notif-close-game-mon"
      handler_dir       = "notif_close_game_alert"
      description       = "Monday primetime close-game alert (within 10 pts)."
      cron_expression   = "cron(0 20 ? * MON *)" # Mon 20:00 ET
      schedule_timezone = "America/New_York"
    },
    {
      name              = "notif-worldcup-movement"
      handler_dir       = "notif_worldcup_movement"
      description       = "Tuesday: World Cup clinch/elimination/line-flip transitions."
      cron_expression   = "cron(0 10 ? * TUE *)" # Tue 10:00 ET, after recap
      schedule_timezone = "America/New_York"
    },
    # AI Review (F3) — weekly recap cron.
    # Fires Tue 14:00 ET — far enough past Monday Night Football (~23:30 ET
    # Mon) for Sleeper's nfl_state.week to have incremented, and 5h past
    # `notif-weekly-recap` (09:00 ET) so the two products land separately
    # in inboxes. ET is interpreted directly by EventBridge via
    # schedule_timezone, so no DST math needed (same convention as the
    # other five entries above).
    # IAM coverage: existing wildcards in iam_lambdas.tf cover the new
    # function name + Dynamo R/W on xomper-ai-memories / xomper-ai-reports.
    {
      name              = "notif-ai-review-weekly"
      handler_dir       = "notif_ai_review_weekly"
      description       = "Tuesday afternoon: AI-generated weekly league newsletter (Claude Haiku)"
      cron_expression   = "cron(0 14 ? * TUE *)" # Tue 14:00 ET, post-MNF
      schedule_timezone = "America/New_York"
    },
  ]

  # Same env block as locals.lambda_variables but kept separate so we can
  # tune scheduled-lambda-specific config without polluting the API set.
  scheduled_lambda_variables = local.lambda_variables
}

# 1. Lambda function per schedule
resource "aws_lambda_function" "scheduled" {
  for_each         = { for l in local.scheduled_lambdas : l.name => l }
  function_name    = "${var.app_name}-${each.value.name}"
  description      = each.value.description
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = 60 # scheduled jobs do more work; allow more headroom
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = local.scheduled_lambda_variables
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, tomap({
    "name"        = "${var.app_name}-${each.value.name}",
    "lambda_type" = "scheduled",
    "handler_dir" = each.value.handler_dir,
  }))

  lifecycle {
    ignore_changes = [
      description,
      filename,
      source_code_hash,
      layers
    ]
  }
}

# 2. EventBridge rule per schedule
resource "aws_cloudwatch_event_rule" "scheduled_notif" {
  for_each            = { for l in local.scheduled_lambdas : l.name => l }
  name                = "${var.app_name}-${each.value.name}-schedule"
  description         = "Schedule for ${each.value.name}: ${each.value.cron_expression}"
  schedule_expression = each.value.cron_expression

  tags = merge(local.standard_tags, tomap({
    "name" = "${var.app_name}-${each.value.name}-schedule"
  }))
}

# 3. Wire each rule to its target lambda
resource "aws_cloudwatch_event_target" "scheduled_notif" {
  for_each  = { for l in local.scheduled_lambdas : l.name => l }
  rule      = aws_cloudwatch_event_rule.scheduled_notif[each.key].name
  target_id = "${var.app_name}-${each.value.name}-target"
  arn       = aws_lambda_function.scheduled[each.key].arn
}

# 4. Allow EventBridge to invoke each lambda
resource "aws_lambda_permission" "scheduled_notif_invoke" {
  for_each      = { for l in local.scheduled_lambdas : l.name => l }
  statement_id  = "AllowExecutionFromEventBridge-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduled[each.key].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled_notif[each.key].arn
}
