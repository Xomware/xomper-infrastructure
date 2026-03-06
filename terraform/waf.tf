# CloudFront WAF (must be CLOUDFRONT scope)
module "waf_cloudfront" {
  source   = "git::https://github.com/Xomware/waf.git?ref=v2.0.0"
  app_name = "${var.app_name}-cloudfront"
  scope    = "CLOUDFRONT"
  tags     = local.standard_tags
}

# API Gateway WAF (REGIONAL scope)
module "waf_api_gateway" {
  source     = "git::https://github.com/Xomware/waf.git?ref=v2.0.0"
  app_name   = "${var.app_name}-api-gateway"
  scope      = "REGIONAL"
  rate_limit = 2000
  tags       = local.standard_tags
}

# WAF association must be separate (can't use count with unknown values)
resource "aws_wafv2_web_acl_association" "api_gateway" {
  web_acl_arn  = module.waf_api_gateway.web_acl_arn
  resource_arn = module.api.stage_arn
}
