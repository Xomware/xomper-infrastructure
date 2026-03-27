# API Gateway Account (singleton per AWS account)
resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

locals {
  email_endpoints = [
    for l in local.email_lambdas : {
      name        = l.name
      path_part   = l.path_part
      http_method = l.http_method
      invoke_arn  = aws_lambda_function.email[l.name].invoke_arn
    }
  ]

  api_endpoints = [
    for l in local.api_lambdas : {
      name        = l.name
      path_part   = l.path_part
      http_method = l.http_method
      invoke_arn  = aws_lambda_function.api[l.name].invoke_arn
    }
  ]
}

module "api" {
  source = "git::https://github.com/domgiordano/api-gateway-service.git?ref=v2.2.0"

  app_name = var.app_name
  # NOTE: Stage is "dev" in production for historical reasons. Do NOT rename --
  # there is a custom domain base path mapping that depends on this stage name.
  stage_name            = "dev"
  authorizer_invoke_arn = aws_lambda_function.authorizer.invoke_arn
  authorizer_role_arn   = aws_iam_role.authorizer_role.arn
  tags                  = local.standard_tags
  allow_headers         = local.api_allow_headers
  allow_origin          = "https://${local.domain_name}"

  domain_name     = local.api_domain_name
  certificate_arn = aws_acm_certificate_validation.api.certificate_arn

  services = {
    email = {
      path_prefix = "email"
      endpoints   = local.email_endpoints
    }
    profiles = {
      path_prefix = "profiles"
      endpoints   = [for e in local.api_endpoints : e if can(regex("^profiles-", e.name))]
    }
    users = {
      path_prefix = "users"
      endpoints   = [for e in local.api_endpoints : e if can(regex("^users-", e.name))]
    }
    rules = {
      path_prefix = "rules"
      endpoints   = [for e in local.api_endpoints : e if can(regex("^rules-", e.name))]
    }
    votes = {
      path_prefix = "votes"
      endpoints   = [for e in local.api_endpoints : e if can(regex("^votes-", e.name))]
    }
    taxi = {
      path_prefix = "taxi-steals"
      endpoints   = [for e in local.api_endpoints : e if can(regex("^taxi-steals-", e.name))]
    }
    drafts = {
      path_prefix = "drafts"
      endpoints   = [for e in local.api_endpoints : e if can(regex("^drafts-", e.name))]
    }
    matchups = {
      path_prefix = "matchups"
      endpoints   = [for e in local.api_endpoints : e if can(regex("^matchups-", e.name))]
    }
    standings = {
      path_prefix = "standings"
      endpoints   = [for e in local.api_endpoints : e if can(regex("^standings-", e.name))]
    }
    champions = {
      path_prefix = "champions"
      endpoints   = [for e in local.api_endpoints : e if can(regex("^champions-", e.name))]
    }
  }
}
