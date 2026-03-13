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
