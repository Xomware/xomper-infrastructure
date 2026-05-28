# =============================================================================
# Admin Portal F5 — CloudWatch Log Viewer IAM Scope
# =============================================================================
# Grants `logs:FilterLogEvents` to the shared xomper-lambda-exec role against
# ONLY the 10 allowlisted lambda log groups consumed by the Admin Portal Log
# Viewer (api_admin_logs_query handler).
#
# Approach: Option B from the F5 plan — additive scoped policy attached to the
# existing shared role. This avoids the api_lambdas for-each surgery needed to
# carve a per-lambda role override (Option A). The handler ALSO enforces the
# same allowlist at runtime via ADMIN_LOG_GROUP_ALLOWLIST in
# lambdas/common/constants.py, so any non-allowlisted log_group query param
# returns 400 before boto3 is invoked.
#
# Allowlist (must be kept in sync with the backend dict — see F5 plan):
#   1. xomper-api-admin-ai-review-postdraft-trigger
#   2. xomper-api-admin-ai-review-preseason-trigger
#   3. xomper-api-admin-ai-review-weekly-trigger
#   4. xomper-notif-ai-review-weekly
#   5. xomper-notif-weekly-recap
#   6. xomper-api-admin-email-test
#   7. xomper-api-admin-reports-flag
#   8. xomper-api-admin-users-update
#   9. xomper-api-admin-leagues-update
#  10. xomper-api-admin-audit-list
#
# NOTE: The shared role's existing `CloudWatchLogs` statement in iam_lambdas.tf
# also grants logs:FilterLogEvents under the broader `/aws/lambda/${var.app_name}*`
# wildcard (which transitively covers these 10). This dedicated policy makes the
# F5 surface explicit + reviewable and documents the read-side audit set.
# =============================================================================

locals {
  admin_logs_allowlist = [
    "xomper-api-admin-ai-review-postdraft-trigger",
    "xomper-api-admin-ai-review-preseason-trigger",
    "xomper-api-admin-ai-review-weekly-trigger",
    "xomper-notif-ai-review-weekly",
    "xomper-notif-weekly-recap",
    "xomper-api-admin-email-test",
    "xomper-api-admin-reports-flag",
    "xomper-api-admin-users-update",
    "xomper-api-admin-leagues-update",
    "xomper-api-admin-audit-list",
  ]

  admin_logs_allowlist_arns = [
    for name in local.admin_logs_allowlist :
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.web_app_account.account_id}:log-group:/aws/lambda/${name}:*"
  ]
}

data "aws_iam_policy_document" "admin_logs_query_read" {
  statement {
    sid       = "AdminLogsQueryFilterLogEvents"
    effect    = "Allow"
    actions   = ["logs:FilterLogEvents"]
    resources = local.admin_logs_allowlist_arns
  }
}

resource "aws_iam_role_policy" "admin_logs_query_read" {
  name   = "${var.app_name}-admin-logs-query-read"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.admin_logs_query_read.json
}
