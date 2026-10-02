# =============================================================================
# SNS Platform Application for APNs (iOS Push Notifications)
# Uses token-based auth (.p8 key) -- no annual certificate renewal required.
# =============================================================================

resource "aws_sns_platform_application" "apns" {
  name                     = "${var.app_name}-apns"
  platform                 = "APNS"
  platform_credential      = var.apns_platform_credential
  platform_principal       = var.apns_key_id
  apple_platform_team_id   = var.apns_team_id
  apple_platform_bundle_id = var.apns_bundle_id

  # The AWS provider sends a key change without the team and bundle IDs, so SNS reads it
  # as a certificate update and rejects it. Rotate the key with
  # `aws sns set-platform-application-attributes`, passing all four attributes at once.
  lifecycle {
    ignore_changes = [platform_credential, platform_principal]
  }
}
