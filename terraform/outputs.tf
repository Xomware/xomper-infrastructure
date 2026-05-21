# =============================================================================
# Outputs
# =============================================================================

# API Gateway
output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = module.api.rest_api_id
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = "https://${local.api_domain_name}"
}

output "api_gateway_stage_arn" {
  description = "API Gateway stage ARN"
  value       = module.api.stage_arn
}

# CloudFront / Web Hosting
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.web.cloudfront_distribution_id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = module.web.cloudfront_distribution_arn
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for web hosting"
  value       = module.web.s3_bucket_arn
}

output "website_url" {
  description = "Website URL"
  value       = "https://${local.domain_name}"
}

# KMS
output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.web_app.arn
}

# IAM Roles
output "lambda_role_arn" {
  description = "IAM role ARN for API Lambda functions"
  value       = aws_iam_role.lambda_role.arn
}

output "authorizer_role_arn" {
  description = "IAM role ARN for the authorizer Lambda"
  value       = aws_iam_role.authorizer_role.arn
}

# SES
output "ses_domain_identity_arn" {
  description = "SES domain identity ARN"
  value       = aws_ses_domain_identity.xomper.arn
}

# DynamoDB Table ARNs
output "dynamodb_table_arns" {
  description = "Map of DynamoDB table ARNs"
  value = {
    profiles            = aws_dynamodb_table.profiles.arn
    whitelisted_users   = aws_dynamodb_table.whitelisted_users.arn
    rule_proposals      = aws_dynamodb_table.rule_proposals.arn
    rule_votes          = aws_dynamodb_table.rule_votes.arn
    taxi_steal_requests = aws_dynamodb_table.taxi_steal_requests.arn
    draft_history       = aws_dynamodb_table.draft_history.arn
    matchup_history     = aws_dynamodb_table.matchup_history.arn
    season_standings    = aws_dynamodb_table.season_standings.arn
    league_champions    = aws_dynamodb_table.league_champions.arn
  }
}

# AI Review (F0) — direct table name/arn outputs for downstream reference
# (backend deploy scripts, future cross-stack lookups, manual debugging).
output "ai_reports_table_name" {
  description = "DynamoDB table name for AI Review reports"
  value       = aws_dynamodb_table.ai_reports.name
}

output "ai_reports_table_arn" {
  description = "DynamoDB table ARN for AI Review reports"
  value       = aws_dynamodb_table.ai_reports.arn
}

# Route53
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.web_zone.zone_id
}
