# =============================================================================
# DynamoDB Tables for Supabase Migration
# All tables use PAY_PER_REQUEST billing, KMS encryption, and PITR.
# =============================================================================

locals {
  dynamodb_kms_key_arn = aws_kms_key.web_app.arn
}

# --- Profiles ---
resource "aws_dynamodb_table" "profiles" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-profiles"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-profiles" })
}

# --- Whitelisted Users ---
resource "aws_dynamodb_table" "whitelisted_users" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-whitelisted-users"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "email"

  attribute {
    name = "email"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-whitelisted-users" })
}

# --- Rule Proposals ---
resource "aws_dynamodb_table" "rule_proposals" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-rule-proposals"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "league_id"
    type = "S"
  }

  global_secondary_index {
    name            = "league_id-index"
    hash_key        = "league_id"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-rule-proposals" })
}

# --- Rule Votes ---
resource "aws_dynamodb_table" "rule_votes" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-rule-votes"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "proposal_id"
  range_key                   = "user_id"

  attribute {
    name = "proposal_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-rule-votes" })
}

# --- Taxi Steal Requests ---
resource "aws_dynamodb_table" "taxi_steal_requests" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-taxi-steal-requests"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "league_id"
  range_key                   = "player_id"

  attribute {
    name = "league_id"
    type = "S"
  }

  attribute {
    name = "player_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-taxi-steal-requests" })
}

# --- Draft History ---
resource "aws_dynamodb_table" "draft_history" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-draft-history"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "draft_id"
  range_key                   = "pick_no"

  attribute {
    name = "draft_id"
    type = "S"
  }

  attribute {
    name = "pick_no"
    type = "N"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-draft-history" })
}

# --- Matchup History ---
resource "aws_dynamodb_table" "matchup_history" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-matchup-history"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "league_id_season_week"
  range_key                   = "matchup_id"

  attribute {
    name = "league_id_season_week"
    type = "S"
  }

  attribute {
    name = "matchup_id"
    type = "N"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-matchup-history" })
}

# --- Season Standings ---
resource "aws_dynamodb_table" "season_standings" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-season-standings"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "league_id"
  range_key                   = "season"

  attribute {
    name = "league_id"
    type = "S"
  }

  attribute {
    name = "season"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-season-standings" })
}

# --- League Champions ---
resource "aws_dynamodb_table" "league_champions" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-league-champions"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "league_id"
  range_key                   = "season"

  attribute {
    name = "league_id"
    type = "S"
  }

  attribute {
    name = "season"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-league-champions" })
}

# --- Notification Activity Log (admin portal) ---
# Drives the iOS Admin portal's activity feed. Every push +
# email send writes a row from inside ses_helper.send_email and
# sns_helper.send_push_to_users. PK = day (S, "YYYY-MM-DD"),
# SK = id (S, "{epoch_ms:013d}#{uuid_short}") — sorts newest-last
# inside the partition so reads with ScanIndexForward=false stream
# newest-first.
resource "aws_dynamodb_table" "notification_log" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-notification-log"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "day"
  range_key                   = "id"

  attribute {
    name = "day"
    type = "S"
  }

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-notification-log" })
}

# --- World Cup Snapshots (per-week clinch state) ---
# Drives `notif_worldcup_movement` — the lambda diffs the current
# week's computed clinch status against the prior snapshot to decide
# which managers get a transition push. PK = league_id#season,
# SK = week, item value is the per-team status map.
resource "aws_dynamodb_table" "worldcup_snapshots" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-worldcup-snapshots"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "league_id_season"
  range_key                   = "week"

  attribute {
    name = "league_id_season"
    type = "S"
  }

  attribute {
    name = "week"
    type = "N"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-worldcup-snapshots" })
}

# --- AI Reports (AI Review F0) ---
# Stores Claude-generated league reports (post-draft, preseason, weekly).
# PK = "LEAGUE#<league_id>" (S), SK = "REPORT#<report_type>#<period>" (S).
# GSI `created-at-index` reuses PK and ranges on `created_at` (ISO 8601)
# for newest-first archive queries via the /ai-reports/list endpoint.
# Body lives in `body_markdown` (S); metadata Map carries model, prompt
# version, token usage, etc. No CreateTable/DeleteTable IAM — runtime
# lambda role only reads + writes via the existing `${var.app_name}*`
# wildcard in `iam_lambdas.tf:DynamoDBRuntime`.
resource "aws_dynamodb_table" "ai_reports" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-ai-reports"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "pk"
  range_key                   = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "created-at-index"
    hash_key        = "pk"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-ai-reports" })
}

# --- AI Memories (AI Review F3) ---
# Stores Claude-generated season memories appended every Tuesday by the
# weekly recap orchestrator. Lookback (default 6 newest) is injected into
# the next week's user prompt so the recap carries continuity.
# PK = "LEAGUE#<league_id>#SEASON#<year>" (S) — season-scoped so a fresh
# season (e.g. 2027) starts empty without manual purge.
# SK = "MEMORY#<week:02d>#<memory_id>" (S) where memory_id is a uuid4 hex.
# Additional attributes (memory_id, season, week, manager_user_id, text,
# sentiment, created_at) are item attributes only — not part of the key
# schema, so they don't need declaring on the resource.
# No GSI in v1 — the only access pattern is "Query PK + SK begins_with
# MEMORY# with ScanIndexForward=false, Limit=N" which works on the base
# table. Add a GSI in v1.1 only if a per-manager query becomes a thing.
# IAM coverage: existing `${var.app_name}*` wildcard in iam_lambdas.tf:
# DynamoDBRuntime covers R/W on this table.
resource "aws_dynamodb_table" "ai_memories" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-ai-memories"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "pk"
  range_key                   = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-ai-memories" })
}

# --- Device Tokens (Push Notifications) ---
resource "aws_dynamodb_table" "device_tokens" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-device-tokens"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "user_id"
  range_key                   = "device_token"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "device_token"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-device-tokens" })
}
