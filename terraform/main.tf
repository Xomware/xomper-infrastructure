terraform {
  backend "s3" {
    bucket         = "xomware-terraform-state"
    key            = "xomper/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "xomware-terraform-locks"
    encrypt        = true
  }
}

data "aws_caller_identity" "web_app_account" {
  provider = aws
}
