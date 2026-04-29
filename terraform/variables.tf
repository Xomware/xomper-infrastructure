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
