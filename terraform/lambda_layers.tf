# LAMBDA LAYER RESOURCES

resource "aws_lambda_layer_version" "lambda_layer" {
  description = "Currently managed by ${var.app_name}"
  layer_name  = "${var.app_name}-shared-packages"

  filename            = "./templates/lambda_stub.zip"
  source_code_hash    = filebase64sha256("./templates/lambda_stub.zip")
  compatible_runtimes = [var.lambda_runtime]

  lifecycle {
    ignore_changes = [
      description,
      filename,
      source_code_hash
    ]
  }
}

# The resource above only ever holds the stub zip -- real dependencies are
# published by the backend's own workflow. So its .arn is pinned to whatever
# version Terraform last created, which is version 26 while the published
# layer is at 67.
#
# Every function Terraform creates therefore starts on a years-old layer and
# fails at import. xomper-api-players-list died on
# "No module named 'lambdas'" for exactly this reason, and
# xomper-api-profiles-get is still sitting on 26.
#
# This data source resolves whatever was actually published last. Existing
# functions carry ignore_changes = [layers], so this only affects newly created
# ones -- it will not churn the fleet.
data "aws_lambda_layer_version" "shared_latest" {
  layer_name = aws_lambda_layer_version.lambda_layer.layer_name
}
