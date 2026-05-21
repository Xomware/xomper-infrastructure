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

  device_endpoints = [
    for l in local.api_lambdas : {
      name        = l.name
      path_part   = l.path_part
      http_method = l.http_method
      invoke_arn  = aws_lambda_function.api[l.name].invoke_arn
    } if startswith(l.name, "device-")
  ]

  admin_endpoints = [
    for l in local.api_lambdas : {
      name        = l.name
      path_part   = l.path_part
      http_method = l.http_method
      invoke_arn  = aws_lambda_function.api[l.name].invoke_arn
    } if startswith(l.name, "admin-")
  ]

  ai_reports_endpoints = [
    for l in local.api_lambdas : {
      name        = l.name
      path_part   = l.path_part
      http_method = l.http_method
      invoke_arn  = aws_lambda_function.api[l.name].invoke_arn
    } if startswith(l.name, "ai-reports-")
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
    device = {
      path_prefix = "device"
      endpoints   = local.device_endpoints
    }
    admin = {
      path_prefix = "admin"
      endpoints   = local.admin_endpoints
    }
    ai_reports = {
      path_prefix = "ai-reports"
      endpoints   = local.ai_reports_endpoints
    }
    # New API services (profiles, rules, etc.) will be added during Supabase migration
  }
}
