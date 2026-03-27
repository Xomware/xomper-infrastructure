# =============================================================================
# SSM Parameter Store
# NOTE: lifecycle ignore_changes on tags/tags_all is required because the CI
# user (jarvis-agent) lacks ssm:AddTagsToResource/RemoveTagsToResource.
# =============================================================================

# AWS -- TODO: Remove these after OIDC migration (#75). Kept for now since
# they may still be referenced by running services.
resource "aws_ssm_parameter" "access_key" {
  name        = "/${var.app_name}/aws/ACCESS_KEY"
  description = "AWS Access Key -- remove after OIDC migration (#75)"
  type        = "SecureString"
  value       = var.access_key

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_ssm_parameter" "secret_key" {
  name        = "/${var.app_name}/aws/SECRET_KEY"
  description = "AWS Secret Key -- remove after OIDC migration (#75)"
  type        = "SecureString"
  value       = var.secret_key

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# API
resource "aws_ssm_parameter" "api_secret_key" {
  name        = "/${var.app_name}/api/API_SECRET_KEY"
  description = "Web API Secret Key"
  type        = "SecureString"
  value       = var.api_secret_key

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_ssm_parameter" "api_auth_token" {
  name        = "/${var.app_name}/api/API_AUTH_TOKEN"
  description = "Web API Auth Token"
  type        = "SecureString"
  value       = var.api_access_token

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_ssm_parameter" "api_id" {
  name        = "/${var.app_name}/api/API_ID"
  description = "Web API ID"
  type        = "SecureString"
  value       = module.api.rest_api_id

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# SUPABASE
resource "aws_ssm_parameter" "api_supabase_url" {
  name        = "/${var.app_name}/api/SUPABASE_URL"
  description = "Supabase URL"
  type        = "SecureString"
  value       = var.supabase_url

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_ssm_parameter" "api_supabase_anon_key" {
  name        = "/${var.app_name}/api/SUPABASE_ANON_KEY"
  description = "Supabase ANON key"
  type        = "SecureString"
  value       = var.supabase_anon_key

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}
