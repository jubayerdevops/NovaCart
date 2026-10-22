# ================================================================
# State bucket policy: deny any request that isn't using HTTPS
# ================================================================
data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      var.state_bucket_arn,
      "${var.state_bucket_arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = var.state_bucket_id
  policy = data.aws_iam_policy_document.state_tls_only.json
}

# ================================================================
# GitHub OIDC: lets GitHub Actions log into AWS without stored keys
# ================================================================

# 1. Register GitHub as a trusted identity provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# 2. Trust policy: WHO may become the role (only our repo)
data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

# 3. The role GitHub Actions becomes
resource "aws_iam_role" "github_ci" {
  name                 = "${var.project_name}-github-ci"
  description          = "GitHub Actions in ${var.github_repo} via OIDC (read-only plan)"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

# 4a. Permission: read everything (needed for terraform plan)
resource "aws_iam_role_policy_attachment" "github_ci_readonly" {
  role       = aws_iam_role.github_ci.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# 4b. Permission: read the state file + create/remove the lock file
data "aws_iam_policy_document" "github_ci_state" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid       = "ReadStateAndManageLock"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "github_ci_state" {
  name   = "terraform-state-access"
  role   = aws_iam_role.github_ci.id
  policy = data.aws_iam_policy_document.github_ci_state.json
}