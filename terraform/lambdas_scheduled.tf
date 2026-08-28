###############################################################################
# Scheduled notification lambdas (EventBridge cron triggers).
#
# Pairs with xomper-back-end:lambdas/notif_*/handler.py.
# All four reuse the existing lambda IAM role + layer; no API Gateway
# integration. EventBridge fires each on its cron rule, the handler reads
# Supabase + Sleeper, and emits push (and optionally email) via the
# existing send_push_to_users / send_emails_concurrently infra.
#
# TODO: aws_cloudwatch_event_rule does NOT support schedule_timezone.
# All schedule_timezone fields in local.scheduled_lambdas are ignored.
# As a workaround every cron_expression below is encoded directly in UTC
# (pinned to EDT, so playoffs/offseason drift 1 hour earlier — acceptable
# since all fire at reasonable hours). To fix properly, migrate to
# `aws_scheduler_schedule` which natively supports timezone.
###############################################################################

locals {
  scheduled_lambdas = [
    {
      name            = "notif-weekly-recap"
      handler_dir     = "notif_weekly_recap"
      description     = "Tuesday morning: per-manager weekly matchup recap push."
      cron_expression = "cron(0 13 ? * TUE *)" # Tue 13:00 UTC = 9am EDT / 8am EST
      # ignored by aws_cloudwatch_event_rule — UTC cron is the source of truth
      schedule_timezone = "America/New_York"
    },
    {
      name            = "notif-lineup-not-set"
      handler_dir     = "notif_lineup_not_set"
      description     = "Sunday morning reminder: starters on bye / OUT."
      cron_expression = "cron(0 15 ? * SUN *)" # Sun 15:00 UTC = 11am EDT / 10am EST
      # ignored by aws_cloudwatch_event_rule — UTC cron is the source of truth
      schedule_timezone = "America/New_York"
    },
    {
      name        = "notif-close-game-sun"
      handler_dir = "notif_close_game_alert"
      description = "Sunday primetime close-game alert (within 10 pts)."
      # Sun 8pm EDT = 00:00 UTC the NEXT day, so day-of-week shifts SUN -> MON.
      # During EST window this fires at 7pm ET on Sunday instead of 8pm.
      cron_expression = "cron(0 0 ? * MON *)" # Mon 00:00 UTC = Sun 8pm EDT / 7pm EST
      # ignored by aws_cloudwatch_event_rule — UTC cron is the source of truth
      schedule_timezone = "America/New_York"
    },
    {
      name        = "notif-close-game-mon"
      handler_dir = "notif_close_game_alert"
      description = "Monday primetime close-game alert (within 10 pts)."
      # Mon 8pm EDT = 00:00 UTC the NEXT day, so day-of-week shifts MON -> TUE.
      # During EST window this fires at 7pm ET on Monday instead of 8pm.
      cron_expression = "cron(0 0 ? * TUE *)" # Tue 00:00 UTC = Mon 8pm EDT / 7pm EST
      # ignored by aws_cloudwatch_event_rule — UTC cron is the source of truth
      schedule_timezone = "America/New_York"
    },
    {
      name            = "notif-worldcup-movement"
      handler_dir     = "notif_worldcup_movement"
      description     = "Tuesday: World Cup clinch/elimination/line-flip transitions."
      cron_expression = "cron(0 14 ? * TUE *)" # Tue 14:00 UTC = 10am EDT / 9am EST, after recap
      # ignored by aws_cloudwatch_event_rule — UTC cron is the source of truth
      schedule_timezone = "America/New_York"
    },
    # AI Review (F3) — weekly recap cron.
    # Fires Tue 18:00 UTC, which lands post-MNF (~23:30 ET Mon) so Sleeper's
    # nfl_state.week has incremented, and several hours past `notif-weekly-recap`
    # so the two products land separately in inboxes.
    #
    # Cron expression is in UTC because aws_cloudwatch_event_rule does NOT
    # support schedule_timezone (see the TODO at the top of this file — the
    # schedule_timezone attribute below is silently ignored by AWS). To get
    # ET-aware behavior without migrating resources we encode the UTC time
    # directly, which means DST drift is acceptable for this cron:
    #   - 18:00 UTC = 14:00 EDT during EDT window (Mar–Nov, regular season)
    #   - 18:00 UTC = 13:00 EST during EST window (Nov–Mar, playoffs)
    # Both windows are post-lunch Tuesday — fine for a weekly newsletter.
    #
    # IAM coverage: existing wildcards in iam_lambdas.tf cover the new
    # function name + Dynamo R/W on xomper-ai-memories / xomper-ai-reports.
    {
      name        = "notif-ai-review-weekly"
      handler_dir = "notif_ai_review_weekly"
      description = "Wednesday afternoon: AI-generated weekly league recap (Claude Haiku)"
      # Moved from Tue 18:00 -> Wed 18:00 UTC so the Wed-morning Week
      # Preview (9am ET) gets the morning slot and the AI recap follows
      # later that afternoon — keeps Tuesday from being inbox-spammed
      # (Tue already has data recap 9am + WC push 10am).
      cron_expression = "cron(0 18 ? * WED *)" # Wed 18:00 UTC = 2pm EDT / 1pm EST
      # ignored by aws_cloudwatch_event_rule — UTC cron is the source of truth
      schedule_timezone = "America/New_York"
    },

    # Week Preview (Phase 2). Wednesday-morning forward-looking
    # newsletter — AI body + standings + WC tables. Same env block,
    # same IAM coverage (SES, Dynamo, SSM, Anthropic via env). Fires
    # before waiver claims process so the preview is actionable.
    # Cron-settings + admin trigger let admin gate broadcast and
    # manually re-fire. Backend dir: lambdas/notif_week_preview/ .
    {
      name            = "notif-week-preview"
      handler_dir     = "notif_week_preview"
      description     = "Wednesday morning: Week N preview newsletter (Claude Haiku)"
      cron_expression = "cron(0 14 ? * WED *)" # Wed 14:00 UTC = 9am ET
      # ignored by aws_cloudwatch_event_rule — UTC cron is the source of truth
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
  layers           = [data.aws_lambda_layer_version.shared_latest.arn]
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
