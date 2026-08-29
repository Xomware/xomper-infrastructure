#**********************
# GitHub Actions OIDC — the Terraform workflow itself
#**********************
#
# Terraform needs broad authority by nature: it creates and destroys everything
# in this stack. Hand-writing a least-privilege policy for it would break on
# every new resource type and rot into a permanent maintenance tax, so the apply
# role carries AdministratorAccess.
#
# What changes is not the authority, it is the credential. Today that authority
# is a STATIC access key belonging to an IAM user in the Admin group, copied
# into every repo, never rotated, and valid until someone revokes it. After this
# it is a token that lasts an hour, is scoped to one repository, and cannot be
# stolen from a laptop.
#
# Two roles rather than one, because plan and apply do not deserve the same
# authority:
#
#   plan   ReadOnlyAccess. Trusted from ANY ref, including pull requests, so PR
#          plans keep working. A pull request can therefore never reach anything
#          that mutates.
#
#   apply  AdministratorAccess. Trusted ONLY from a push to the default branch,
#          so no PR context can assume it even if secrets were somehow exposed.

data "aws_iam_policy_document" "terraform_plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for subject in var.github_infrastructure_subjects : "${subject}:*"]
    }
  }
}

data "aws_iam_policy_document" "terraform_apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Default branch only -- NOT `:*`. This is the difference between "a push to
    # master can change infrastructure" and "anything that can open a pull
    # request can change infrastructure".
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for subject in var.github_infrastructure_subjects : "${subject}:ref:refs/heads/${var.default_branch}"]
    }
  }
}

resource "aws_iam_role" "terraform_plan" {
  name               = "${var.app_name}-github-actions-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.terraform_plan_trust.json
  tags               = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-github-actions-terraform-plan" }))
}

resource "aws_iam_role" "terraform_apply" {
  name               = "${var.app_name}-github-actions-terraform-apply"
  assume_role_policy = data.aws_iam_policy_document.terraform_apply_trust.json
  tags               = merge(local.standard_tags, tomap({ "name" = "${var.app_name}-github-actions-terraform-apply" }))
}

resource "aws_iam_role_policy_attachment" "terraform_plan" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "terraform_apply" {
  role       = aws_iam_role.terraform_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# The one thing admin should not be able to do here. Nothing in any Xomware
# stack manages IAM users, so denying this costs nothing -- and it is precisely
# how a compromised workflow would turn an hour-long token into a permanent
# credential. Deny beats Allow in IAM, so this holds even under
# AdministratorAccess.
data "aws_iam_policy_document" "terraform_apply_guardrails" {
  statement {
    sid    = "NoPersistentCredentials"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:UpdateAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:CreateSAMLProvider",
      "iam:UpdateSAMLProvider",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "terraform_apply_guardrails" {
  name   = "guardrails"
  role   = aws_iam_role.terraform_apply.id
  policy = data.aws_iam_policy_document.terraform_apply_guardrails.json
}

output "terraform_plan_role_arn" {
  description = "Read-only role the Terraform workflow assumes for plans, including on pull requests"
  value       = aws_iam_role.terraform_plan.arn
}

output "terraform_apply_role_arn" {
  description = "Admin role the Terraform workflow assumes only for an apply on the default branch"
  value       = aws_iam_role.terraform_apply.arn
}
