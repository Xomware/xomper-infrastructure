variable "access_key" {
  description = "AWS access key for SSM parameter storage."
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "AWS secret key for SSM parameter storage."
  type        = string
  sensitive   = true
}

variable "app_name" {
  description = "The name for the application."
  default     = "xomper"
}

variable "domain_suffix" {
  description = "Suffix for the domain of the app."
  default     = ".xomware.com"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "cloudfront_origin_path" {
  type        = string
  default     = ""
  description = "Optional element for cloudfront distribution that causes CloudFront to request your content from a directory in your Amazon S3 bucket or your custom origin."
}

variable "us_canada_only" {
  type        = bool
  default     = true
  description = "If a georestriction should be placed on the distribution to only provide access to the US and Canada"
}

variable "custom_error_response_page_path" {
  type        = string
  default     = "/index.html"
  description = "custom error response page path."
}

variable "retain_on_delete" {
  type        = bool
  default     = false
  description = "Disables the distribution instead of deleting it when destroying the resource through Terraform."
}

variable "minimum_tls_version" {
  type        = string
  default     = "TLSv1.2_2018"
  description = "minimum tls version"
}

variable "enable_cloudfront_cache" {
  type        = bool
  default     = true
  description = "This variable controls the cloudfront cache. Setting this to false will set the default_ttl and max_ttl values to zero"
}

# Lambda
variable "lambda_runtime" {
  type    = string
  default = "python3.13"
}

variable "lambda_trace_mode" {
  type    = string
  default = "Active"
}

variable "lambda_memory_size" {
  description = "Memory size for API Lambda functions in MB"
  type        = number
  default     = 1024
}

variable "lambda_timeout" {
  description = "Timeout for API Lambda functions in seconds"
  type        = number
  default     = 900
}

variable "authorizer_memory_size" {
  description = "Memory size for the authorizer Lambda in MB"
  type        = number
  default     = 256
}

variable "authorizer_timeout" {
  description = "Timeout for the authorizer Lambda in seconds"
  type        = number
  default     = 30
}

# API
variable "api_access_token" {
  description = "API access token"
  sensitive   = true
}

variable "api_secret_key" {
  description = "API Secret Key for FE / BE to use"
  sensitive   = true
}

# SUPABASE
variable "supabase_url" {
  description = "Supabase Project URL"
  type        = string
  sensitive   = true
}

variable "supabase_anon_key" {
  description = "Supabase Anon Key"
  type        = string
  sensitive   = true
}

variable "supabase_service_key" {
  description = "Supabase service-role key — read access to RLS-protected whitelisted_* tables for scheduled notification lambdas."
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key for the AI Review feature. Sourced from the ANTHROPIC_API_KEY GitHub Secret on the xomper-infrastructure repo via TF_VAR_anthropic_api_key in the terraform.yml workflow."
  type        = string
  sensitive   = true
}

# Push Notifications (APNs)
variable "apns_team_id" {
  description = "Apple Developer Team ID for APNs"
  type        = string
  sensitive   = true
}

variable "apns_key_id" {
  description = "APNs Auth Key ID"
  type        = string
  sensitive   = true
}

variable "apns_bundle_id" {
  description = "iOS app bundle identifier"
  type        = string
  default     = "com.Xomware.Xomper"
}

variable "apns_platform_credential" {
  description = "APNs .p8 auth key contents"
  type        = string
  sensitive   = true
}

# Email Service
variable "from_email" {
  description = "Email address to send from via SES"
  type        = string
  default     = "noreply@xomper.xomware.com"
}

# Tags
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "domgiordano"
}

# COGNITO
# The `xomware-users` pool and the `xomper-client` app client are owned by
# xomware-infrastructure — this repo only consumes them. Defaults are set to
# the live values because neither identifier is a secret: both ship in the
# frontend bundle, and Cognito treats the app client as public (no secret).
variable "cognito_user_pool_id" {
  description = "Shared xomware-users Cognito pool id"
  type        = string
  default     = "us-east-1_ZrN8NaaIv"
}

variable "cognito_client_id" {
  description = "xomper-client app client id on the shared pool"
  type        = string
  default     = "38e5sjavoa76ghbl5hpjsapc49"
}

# Read these off the repo, never build them from a name:
#   gh api /repos/<org>/<repo>/actions/oidc/customization/sub -q .sub_claim_prefix
# GitHub uses immutable numeric identifiers on newer repos, and it reports the
# repo's CURRENT name -- several Xomware repos have been renamed since creation.
# Both spellings are listed so a flip in either direction keeps working.

variable "github_frontend_subjects" {
  description = "OIDC subject prefixes allowed to assume the frontend deploy role"
  type        = list(string)
  default = [
    "repo:Xomware/xomper-frontend",
    "repo:Xomware@263047999/xomper-frontend@1052220282",
  ]
}

variable "github_backend_subjects" {
  description = "OIDC subject prefixes allowed to assume the backend deploy role"
  type        = list(string)
  default = [
    "repo:Xomware/xomper-backend",
    "repo:Xomware@263047999/xomper-backend@1054332117",
  ]
}

variable "github_infrastructure_subjects" {
  description = "OIDC subject prefixes for this infrastructure repository"
  type        = list(string)
  default = [
    "repo:Xomware/xomper-infrastructure",
  ]
}

variable "default_branch" {
  description = "Branch a push to which is allowed to run terraform apply"
  type        = string
  default     = "master"
}
