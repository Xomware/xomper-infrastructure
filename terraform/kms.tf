# KMS key for S3 web app bucket. Requires a special policy for CloudFront

resource "aws_kms_key" "web_app" {
  description         = "KMS CMK for Web App S3 bucket"
  enable_key_rotation = true
  tags = {
    "description" = "KMS CMK for web app S3 bucket"
  }
  policy = jsonencode(
    {
      "Id" : "KMSKeyPolicy",
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "Full key access for account root",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : [
              "arn:aws:iam::${local.web_app_account_id}:root"
            ]
          },
          "Action" : [
            "kms:*"
          ],
          "Resource" : "*"
        },
        {
          "Sid" : "Key access for account roles via S3",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : [
              "arn:aws:iam::${local.web_app_account_id}:root"
            ]
          },
          "Action" : [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:Describe*"
          ],
          "Resource" : "*",
          "Condition" : {
            "StringEquals" : {
              "kms:CallerAccount" : local.web_app_account_id,
              "kms:ViaService" : "s3.${var.aws_region}.amazonaws.com"
            }
          }
        },
        {
          "Sid" : "CloudFront key access",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : [
              "cloudfront.amazonaws.com"
            ]
          },
          "Action" : [
            "kms:Decrypt"
          ],
          "Resource" : "*",
          "Condition" : {
            "StringEquals" : {
              "aws:SourceArn" : module.web.cloudfront_distribution_arn
            }
          }
        }
      ]
    }
  )
}
resource "aws_kms_alias" "web_app" {
  name          = "alias/kms-for-${var.app_name}"
  target_key_id = aws_kms_key.web_app.key_id
}

resource "aws_kms_alias" "xomper_dynamodb" {
  name          = "alias/xomper-dynamodb"
  target_key_id = aws_kms_key.web_app.key_id
}