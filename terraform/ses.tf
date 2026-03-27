# ============================================
# SES - Simple Email Service
# ============================================

# Domain identity for SES
resource "aws_ses_domain_identity" "xomper" {
  domain = local.domain_name
}

# DKIM for better deliverability
resource "aws_ses_domain_dkim" "xomper" {
  domain = aws_ses_domain_identity.xomper.domain
}

# ============================================
# Route53 DNS Records for SES Verification
# ============================================

# Domain verification TXT record
resource "aws_route53_record" "ses_verification" {
  zone_id = data.aws_route53_zone.web_zone.zone_id
  name    = "_amazonses.${local.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.xomper.verification_token]
}

# DKIM CNAME records (SES provides 3 tokens)
resource "aws_route53_record" "ses_dkim" {
  count   = 3
  zone_id = data.aws_route53_zone.web_zone.zone_id
  name    = "${aws_ses_domain_dkim.xomper.dkim_tokens[count.index]}._domainkey.${local.domain_name}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.xomper.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# Wait for domain verification (depends on DNS records)
resource "aws_ses_domain_identity_verification" "xomper" {
  domain = aws_ses_domain_identity.xomper.id

  depends_on = [aws_route53_record.ses_verification]
}

# ============================================
# Mail From Domain (Optional but recommended)
# ============================================

resource "aws_ses_domain_mail_from" "xomper" {
  domain           = aws_ses_domain_identity.xomper.domain
  mail_from_domain = "mail.${local.domain_name}"
}

# MX record for mail from domain
resource "aws_route53_record" "ses_mail_from_mx" {
  zone_id = data.aws_route53_zone.web_zone.zone_id
  name    = "mail.${local.domain_name}"
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

# SPF record for mail from domain
resource "aws_route53_record" "ses_mail_from_spf" {
  zone_id = data.aws_route53_zone.web_zone.zone_id
  name    = "mail.${local.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com ~all"]
}

# DMARC TXT record for email authentication
resource "aws_route53_record" "dmarc" {
  zone_id = data.aws_route53_zone.web_zone.zone_id
  name    = "_dmarc.${local.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = ["v=DMARC1; p=quarantine; rua=mailto:dmarc@${local.domain_name}"]
}
