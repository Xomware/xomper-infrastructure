# =============================================================================
# DynamoDB Tables for Supabase Migration
# All tables use PAY_PER_REQUEST billing, KMS encryption, and PITR.
# =============================================================================

locals {
  dynamodb_kms_key_arn = aws_kms_key.web_app.arn
}

# --- Profiles ---
resource "aws_dynamodb_table" "profiles" {
  name         = "${var.app_name}-profiles"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

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
  name         = "${var.app_name}-whitelisted-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

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
  name         = "${var.app_name}-rule-proposals"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

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
  name         = "${var.app_name}-rule-votes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "proposal_id"
  range_key    = "user_id"

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
  name         = "${var.app_name}-taxi-steal-requests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "league_id"
  range_key    = "player_id"

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
  name         = "${var.app_name}-draft-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "draft_id"
  range_key    = "pick_no"

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
  name         = "${var.app_name}-matchup-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "league_id_season_week"
  range_key    = "matchup_id"

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
  name         = "${var.app_name}-season-standings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "league_id"
  range_key    = "season"

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
  name         = "${var.app_name}-league-champions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "league_id"
  range_key    = "season"

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
  name         = "${var.app_name}-notification-log"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "day"
  range_key    = "id"

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
  name         = "${var.app_name}-worldcup-snapshots"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "league_id_season"
  range_key    = "week"

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

# --- Device Tokens (Push Notifications) ---
resource "aws_dynamodb_table" "device_tokens" {
  name         = "${var.app_name}-device-tokens"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "device_token"

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
