#**********************
# WAF (shared from xomware-infrastructure)
# Consumes shared WAF ACL ARNs via SSM Parameter Store
#**********************

data "aws_ssm_parameter" "shared_cloudfront_waf_arn" {
  name = "/xomware/shared/cloudfront-waf-acl-arn"
}

data "aws_ssm_parameter" "shared_regional_waf_arn" {
  name = "/xomware/shared/regional-waf-acl-arn"
}

# Associate shared regional WAF with API Gateway stage
resource "aws_wafv2_web_acl_association" "api_gateway" {
  web_acl_arn  = data.aws_ssm_parameter.shared_regional_waf_arn.value
  resource_arn = module.api.stage_arn
}

#**********************
# Legacy WAF modules (kept temporarily for Phase 1)
# These will be removed in Phase 2 after CloudFront
# has been updated to use the shared WAF ARN
#**********************

module "waf_cloudfront" {
  source   = "git::https://github.com/Xomware/waf.git?ref=v2.0.0"
  app_name = "${var.app_name}-cloudfront"
  scope    = "CLOUDFRONT"
  tags     = local.standard_tags
}

module "waf_api_gateway" {
  source     = "git::https://github.com/Xomware/waf.git?ref=v2.0.0"
  app_name   = "${var.app_name}-api-gateway"
  scope      = "REGIONAL"
  rate_limit = 2000
  tags       = local.standard_tags
}
