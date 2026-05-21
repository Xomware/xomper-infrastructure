###############################################################################
# CloudWatch Alarms
#
# AI Review (F0) — invocation-count guard
# -----------------------------------------------------------------------------
# The original brainstorm asked for a "$5/month cost alarm" against the three
# forthcoming AI Review lambdas (notif_ai_review_post_draft / _preseason /
# _weekly). AWS's native billing metrics (AWS/Billing → EstimatedCharges)
# require billing-data export to be enabled in the payer account AND the
# metric is only emitted in us-east-1 — they also do NOT slice by Lambda
# function name or resource tag, so a true "$5/month on these three lambdas
# only" alarm isn't expressible without a custom metric pipeline (Cost
# Explorer API → custom CW metric via a scheduled lambda — overkill for F0).
#
# We instead use an **invocation-count proxy**: at Claude Haiku pricing
# (~$0.001/call typical for our token budget), 50 invocations/day across
# the three lambdas is the worst-case ceiling that keeps us under ~$5/mo.
# This catches a runaway loop or schedule-storm — the realistic failure
# mode — without depending on Cost Explorer wiring.
#
# Aggregation: SUM of `AWS/Lambda` `Invocations` across the three function
# names via a metric_query. Period = 1 day, threshold = 50.
#
# NOTE: These three function names are referenced by the F1/F2/F3 plans —
# they don't exist yet at F0 merge. The alarm will sit in INSUFFICIENT_DATA
# state until F1 ships its first scheduled lambda. That's expected.
###############################################################################

resource "aws_cloudwatch_metric_alarm" "ai_review_invocations_guard" {
  alarm_name          = "${var.app_name}-ai-review-invocations-guard"
  alarm_description   = "AI Review cost proxy: alarms when the three notif_ai_review_* lambdas combined fire more than 50 times in a day. Sits in INSUFFICIENT_DATA until F1 deploys the first scheduled lambda."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 50
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "total"
    expression  = "SUM(METRICS())"
    label       = "AI Review total daily invocations"
    return_data = true
  }

  metric_query {
    id = "post_draft"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 86400
      stat        = "Sum"
      dimensions = {
        FunctionName = "${var.app_name}-notif-ai-review-post-draft"
      }
    }
  }

  metric_query {
    id = "preseason"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 86400
      stat        = "Sum"
      dimensions = {
        FunctionName = "${var.app_name}-notif-ai-review-preseason"
      }
    }
  }

  metric_query {
    id = "weekly"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 86400
      stat        = "Sum"
      dimensions = {
        FunctionName = "${var.app_name}-notif-ai-review-weekly"
      }
    }
  }

  tags = merge(local.standard_tags, {
    "name"    = "${var.app_name}-ai-review-invocations-guard"
    "feature" = "ai-review"
  })
}
