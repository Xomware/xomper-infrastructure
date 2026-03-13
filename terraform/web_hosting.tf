module "web" {
  source = "git::https://github.com/domgiordano/web-hosting.git?ref=v1.1.0"

  app_name    = var.app_name
  domain_name = local.domain_name
  zone_id     = data.aws_route53_zone.web_zone.zone_id
  tags        = local.standard_tags
  kms_key_arn = aws_kms_alias.web_app.target_key_arn

  waf_acl_arn               = data.aws_ssm_parameter.shared_cloudfront_waf_arn.value
  spa_error_path            = var.custom_error_response_page_path
  geo_restriction_locations = var.us_canada_only ? ["US", "CA"] : []
  enable_cache              = var.enable_cloudfront_cache
  origin_path               = var.cloudfront_origin_path
  minimum_tls_version       = var.minimum_tls_version
  retain_on_delete          = var.retain_on_delete
}
