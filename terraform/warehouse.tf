###############################################################################
# Fantasy data warehouse
#
# Phase 5 of docs/features/xomper-rebrand/PLAN.md, as revised by the two DuckDB
# spikes in tools/duckdb-spike/.
#
# What is deliberately NOT here: a values table.
#
# The original design stored a nightly cross product of formats in DynamoDB,
# keyed PK player_id / SK format_fingerprint. Measurement killed it. Values
# compute on demand in ~10 ms per league (median over 16 real leagues) from a
# 168 KB Parquet of projections, and with projections the inputs are the
# league's own scoring_settings and roster_positions -- which are arbitrary,
# and a grid cannot enumerate arbitrary. So: store projections once, compute
# per request.
#
# The fingerprint still exists as the FantasyCalc cache key, because that IS an
# external API parameterised on isDynasty x numQbs x numTeams x ppr. Per the
# Phase 0.2 measurement only isDynasty x numQbs move values meaningfully, so
# that is roughly 4 cache entries rather than 200 stored combinations.
#
# Cost posture: everything here is on-demand or per-request. Cost Explorer put
# recurring spend at ~$26/month of which compute and storage was ~$1.50 -- the
# bill is WAF and KMS. A year of nightly snapshots is ~4 GB. This tier should
# not move the needle.
###############################################################################

# --- object store ------------------------------------------------------------

resource "aws_s3_bucket" "warehouse" {
  bucket = "${var.app_name}-warehouse"
  tags   = merge(local.standard_tags, { "name" = "${var.app_name}-warehouse" })
}

resource "aws_s3_bucket_public_access_block" "warehouse" {
  bucket                  = aws_s3_bucket.warehouse.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "warehouse" {
  bucket = aws_s3_bucket.warehouse.id
  versioning_configuration { status = "Enabled" }
}

# SSE-S3, not a CMK. This is derived data reconstructable from public APIs, and
# a customer-managed key would cost $1/month plus a KMS request per object read
# for no confidentiality gain. Same reasoning applied to the static site buckets
# after KMS turned out to be the second-largest line on the bill.
resource "aws_s3_bucket_server_side_encryption_configuration" "warehouse" {
  bucket = aws_s3_bucket.warehouse.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "warehouse" {
  bucket = aws_s3_bucket.warehouse.id

  # Nightly snapshots exist so a source outage degrades to stale-but-present.
  # Ninety days is far more history than that needs, and keeps a year of
  # snapshots from accumulating for no reason.
  rule {
    id     = "expire-old-snapshots"
    status = "Enabled"
    filter { prefix = "snapshots/" }
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 14 }
  }
}

# --- player metadata ---------------------------------------------------------
#
# The slimmed /players/nfl projection, including the espn_id / yahoo_id
# crosswalk already present on player.interface.ts. This is what removes the
# ~5 MB dump every browser session currently downloads.

resource "aws_dynamodb_table" "players" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-players"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "playerId"

  attribute {
    name = "playerId"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  # Deviation from the house default, stated rather than silent: PITR is OFF.
  # Every row here is a projection of Sleeper's public /players/nfl dump and is
  # rebuilt by the nightly ingest. Point-in-time recovery bills per GB-month to
  # protect data that a cron reconstructs in seconds. The other tables in this
  # stack hold user-authored state and keep PITR on; this one has nothing to
  # recover that re-running the job would not restore.
  point_in_time_recovery { enabled = false }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-players" })
}

# --- current-week stats ------------------------------------------------------

resource "aws_dynamodb_table" "stats_current" {
  deletion_protection_enabled = true
  name                        = "${var.app_name}-stats-current"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "playerId"
  range_key                   = "seasonWeek"

  attribute {
    name = "playerId"
    type = "S"
  }

  attribute {
    name = "seasonWeek"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  # PITR off for the same reason as the players table: derived from a public
  # endpoint, rebuilt by the weekly ingest.
  point_in_time_recovery { enabled = false }

  tags = merge(local.standard_tags, { "name" = "${var.app_name}-stats-current" })
}

# --- ingest ------------------------------------------------------------------
#
# DuckDB ships as a layer rather than in the function bundle: 53 MB unzipped
# against Lambda's 250 MB ceiling, and it changes far less often than handler
# code. Memory is 1024 MB because the spike measured a 517 MB peak; the default
# 128 MB would OOM.
#
# Runtime is pinned to the account default via var.lambda_runtime, and the
# layer content is managed outside Terraform in the same way as the existing
# shared layer -- filename/source_code_hash are ignored so a code deploy does
# not fight the plan.

resource "aws_lambda_layer_version" "duckdb" {
  description = "DuckDB 1.5.x for the warehouse ingest. Managed by ${var.app_name}."
  layer_name  = "${var.app_name}-duckdb"

  filename            = "./templates/lambda_stub.zip"
  source_code_hash    = filebase64sha256("./templates/lambda_stub.zip")
  compatible_runtimes = [var.lambda_runtime]

  lifecycle {
    ignore_changes = [description, filename, source_code_hash]
  }
}

resource "aws_lambda_function" "warehouse_ingest" {
  function_name    = "${var.app_name}-warehouse-ingest"
  description      = "Nightly: read Sleeper projections in SQL, write Parquet to the warehouse."
  filename         = "./templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("./templates/lambda_stub.zip")
  handler          = "handler.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_role.arn

  layers = [
    aws_lambda_layer_version.lambda_layer.arn,
    aws_lambda_layer_version.duckdb.arn,
  ]

  # Spike peak RSS was 517 MB. 128 MB OOMs; 1024 MB also buys proportionally
  # more CPU, and a ~1 s nightly run costs a fraction of a cent either way.
  memory_size = 1024
  timeout     = 300

  environment {
    variables = {
      APP_NAME         = var.app_name
      WAREHOUSE_BUCKET = aws_s3_bucket.warehouse.id
      PLAYERS_TABLE    = aws_dynamodb_table.players.name
      STATS_TABLE      = aws_dynamodb_table.stats_current.name
    }
  }

  tracing_config {
    mode = var.lambda_trace_mode
  }

  tags = merge(local.standard_tags, {
    "name"        = "${var.app_name}-warehouse-ingest"
    "lambda_type" = "scheduled"
    "handler_dir" = "warehouse_ingest"
  })

  lifecycle {
    ignore_changes = [description, filename, source_code_hash, layers]
  }
}

resource "aws_cloudwatch_log_group" "warehouse_ingest" {
  name              = "/aws/lambda/${aws_lambda_function.warehouse_ingest.function_name}"
  retention_in_days = 14
  tags              = local.standard_tags
}

# 08:00 UTC — after the US night, before anyone opens the app in the morning.
# aws_cloudwatch_event_rule has no schedule_timezone, so UTC is the source of
# truth here as it is for the notification crons.
resource "aws_cloudwatch_event_rule" "warehouse_ingest_nightly" {
  name                = "${var.app_name}-warehouse-ingest-nightly"
  description         = "Nightly projections ingest into the warehouse."
  schedule_expression = "cron(0 8 * * ? *)"
  tags                = local.standard_tags
}

resource "aws_cloudwatch_event_target" "warehouse_ingest_nightly" {
  rule      = aws_cloudwatch_event_rule.warehouse_ingest_nightly.name
  target_id = "${var.app_name}-warehouse-ingest"
  arn       = aws_lambda_function.warehouse_ingest.arn
}

resource "aws_lambda_permission" "warehouse_ingest_nightly" {
  statement_id  = "AllowExecutionFromEventBridgeWarehouseIngest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.warehouse_ingest.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.warehouse_ingest_nightly.arn
}

# --- access ------------------------------------------------------------------
#
# Scoped to the warehouse bucket and its two tables rather than added to the
# shared lambda policy, so the blast radius of the ingest role stays visible.

resource "aws_iam_role_policy" "warehouse_access" {
  name = "${var.app_name}-warehouse-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WarehouseObjects"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${aws_s3_bucket.warehouse.arn}/*"]
      },
      {
        Sid      = "WarehouseList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [aws_s3_bucket.warehouse.arn]
      },
      {
        Sid    = "WarehouseTables"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:GetItem",
          "dynamodb:BatchGetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
        ]
        Resource = [
          aws_dynamodb_table.players.arn,
          aws_dynamodb_table.stats_current.arn,
        ]
      },
    ]
  })
}

# --- exports -----------------------------------------------------------------

output "warehouse_bucket" {
  description = "Parquet store for projections and nightly snapshots."
  value       = aws_s3_bucket.warehouse.id
}

output "warehouse_players_table" {
  value = aws_dynamodb_table.players.name
}

output "warehouse_stats_table" {
  value = aws_dynamodb_table.stats_current.name
}
