# =============================================================================
# SNS Platform Application for APNs (iOS Push Notifications)
# Uses token-based auth (.p8 key) -- no annual certificate renewal required.
# =============================================================================

resource "aws_sns_platform_application" "apns" {
  name                     = "${var.app_name}-apns"
  platform                 = "APNS"
  platform_credential      = var.apns_platform_credential
  apple_platform_team_id   = var.apns_team_id
  apple_platform_bundle_id = var.apns_bundle_id

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-apns" })
}
