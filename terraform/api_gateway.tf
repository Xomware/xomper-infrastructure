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

  # On-demand league valuation. Its lambda lives in warehouse.tf because it
  # needs the DuckDB layer and more memory than the generic API shape gives,
  # so it is referenced directly rather than pulled from local.api_lambdas.
  values_endpoints = [
    {
      name        = "values-compute"
      path_part   = "compute"
      http_method = "POST"
      invoke_arn  = aws_lambda_function.values_compute.invoke_arn
    }
  ]

  # Player metadata, replacing a 14.6 MB per-session download from Sleeper.
  players_endpoints = [
    {
      name        = "players-list"
      path_part   = "list"
      http_method = "GET"
      invoke_arn  = aws_lambda_function.players_list.invoke_arn
    }
  ]

  # ESPN reads, plus connecting and revoking the caller's ESPN cookies. One
  # Lambda behind all three, so the invoke_arn repeats.
  espn_endpoints = [
    {
      name        = "espn-league"
      path_part   = "league"
      http_method = "GET"
      invoke_arn  = aws_lambda_function.espn_league.invoke_arn
    },
    {
      name        = "espn-connect"
      path_part   = "connect"
      http_method = "PUT"
      invoke_arn  = aws_lambda_function.espn_league.invoke_arn
    },
    {
      name        = "espn-disconnect"
      path_part   = "disconnect"
      http_method = "DELETE"
      invoke_arn  = aws_lambda_function.espn_league.invoke_arn
    }
  ]

  # The current user's own record. One Lambda behind all three, so the
  # invoke_arn repeats — the module keys its resources on the endpoint name,
  # not the function.
  me_endpoints = [
    {
      name        = "users-me-profile"
      path_part   = "profile"
      http_method = "GET"
      invoke_arn  = aws_lambda_function.users_me.invoke_arn
    },
    {
      name        = "users-me-display-name"
      path_part   = "display-name"
      http_method = "PUT"
      invoke_arn  = aws_lambda_function.users_me.invoke_arn
    },
    {
      name        = "users-me-sleeper-link"
      path_part   = "sleeper-link"
      http_method = "PUT"
      invoke_arn  = aws_lambda_function.users_me.invoke_arn
    },
    {
      name        = "users-me-sleeper-unlink"
      path_part   = "sleeper-unlink"
      http_method = "DELETE"
      invoke_arn  = aws_lambda_function.users_me.invoke_arn
    },
    {
      name        = "users-me-leagues"
      path_part   = "leagues"
      http_method = "GET"
      invoke_arn  = aws_lambda_function.users_leagues.invoke_arn
    },
    {
      name        = "users-me-follow"
      path_part   = "follow"
      http_method = "PUT"
      invoke_arn  = aws_lambda_function.users_leagues.invoke_arn
    },
    {
      name        = "users-me-unfollow"
      path_part   = "unfollow"
      http_method = "DELETE"
      invoke_arn  = aws_lambda_function.users_leagues.invoke_arn
    }
  ]

  # Public-read announcements endpoint(s). Filtered by exact name == "announcements"
  # so we do NOT accidentally include the four admin-announcements-* lambdas
  # (those live under the /admin/* service block above).
  announcements_endpoints = [
    for l in local.api_lambdas : {
      name        = l.name
      path_part   = l.path_part
      http_method = l.http_method
      invoke_arn  = aws_lambda_function.api[l.name].invoke_arn
    } if l.name == "announcements"
  ]
}

module "api" {
  source = "git::https://github.com/domgiordano/api-gateway-service.git?ref=v2.2.0"

  app_name = var.app_name
  # NOTE: Stage is "dev" in production for historical reasons. Do NOT rename --
  # there is a custom domain base path mapping that depends on this stage name.
  stage_name            = "dev"
  authorizer_invoke_arn = aws_lambda_function.authorizer.invoke_arn
  # Pass empty so the module skips authorizerCredentials. With it
  # unset, API GW invokes the authorizer via the Lambda's
  # resource-based policy (module.api.aws_lambda_permission.authorizer)
  # instead of trying to assume this role. The role we previously
  # passed here (xomper-authorizer-exec) is the authorizer Lambda's
  # *execution* role — it trusts lambda.amazonaws.com only and has no
  # InvokeFunction permission, which caused AuthorizerConfigurationException
  # on every authorized request after the 2026-06-01 deployment replacement.
  authorizer_role_arn = ""
  tags                = local.standard_tags
  allow_headers       = local.api_allow_headers
  allow_origin        = "https://${local.domain_name}"

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
    announcements = {
      path_prefix = "announcements"
      endpoints   = local.announcements_endpoints
    }
    values = {
      path_prefix = "values"
      endpoints   = local.values_endpoints
    }
    players = {
      path_prefix = "players"
      endpoints   = local.players_endpoints
    }
    me = {
      path_prefix = "me"
      endpoints   = local.me_endpoints
    }
    espn = {
      path_prefix = "espn"
      endpoints   = local.espn_endpoints
    }
    # New API services (profiles, rules, etc.) will be added during Supabase migration
  }
}
