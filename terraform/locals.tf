locals {
  domain_name     = "${var.app_name}${var.domain_suffix}"
  api_domain_name = "api.${local.domain_name}"

  # Get the AWS product account id
  web_app_account_id = data.aws_caller_identity.web_app_account.account_id
  standard_tags = {
    "source"      = "terraform"
    "app_name"    = var.app_name
    "environment" = var.environment
    "owner"       = var.owner
  }

  # LAMBDAS
  lambda_variables = {
    APP_NAME             = var.app_name
    DYNAMODB_KMS_ALIAS   = aws_kms_alias.xomper_dynamodb.name
    AWS_ACCOUNT_ID       = data.aws_caller_identity.web_app_account.account_id
    FROM_EMAIL           = var.from_email
    SNS_PLATFORM_APP_ARN = aws_sns_platform_application.apns.arn
    DEVICE_TOKENS_TABLE  = aws_dynamodb_table.device_tokens.name
    # Authorizer needs this to fetch Supabase's JWKS for ES256 verification.
    SUPABASE_URL = var.supabase_url

    # The authorizer accepts Cognito (RS256) alongside Supabase while the
    # platform migrates. The pool is shared estate-wide, so the client id is
    # what scopes a token to Xomper — see lambdas/authorizer/handler.py.
    COGNITO_USER_POOL_ID = var.cognito_user_pool_id
    COGNITO_CLIENT_ID    = var.cognito_client_id

    PLATFORM_USERS_TABLE   = aws_dynamodb_table.platform_users.name
    PLATFORM_FOLLOWS_TABLE = aws_dynamodb_table.platform_follows.name
  }

  # API GW
  # API Gateway allowed headers
  api_allow_headers = [
    "Authorization",
    "Content-Type",
    "X-Amz-Date",
    "X-Amz-Security-Token",
    "X-Api-Key",
    "Origin",
    "Accept",
    "Access-Control-Allow-Origin",
    "Accept-Language"
  ]

}
