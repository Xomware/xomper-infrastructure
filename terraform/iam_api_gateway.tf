## API Gateway IAM for Cloudwatch Logging

data "aws_iam_policy_document" "api_gateway_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name               = "${var.app_name}-api_gateway-logs"
  tags               = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-api_gateway-logs" }))
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role.json
}

data "aws_iam_policy_document" "api_gateway_cloudwatch_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]
    # NOTE: Resource "*" is required by AWS for API Gateway CloudWatch logging.
    # The API Gateway account-level role must have global log permissions.
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch_role_policy" {
  name   = "${var.app_name}-api_gateway_cloudwatch-role-policy"
  role   = aws_iam_role.api_gateway_cloudwatch.id
  policy = data.aws_iam_policy_document.api_gateway_cloudwatch_policy.json
}
