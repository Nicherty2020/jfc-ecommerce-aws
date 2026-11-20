resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  github_sub = "repo:${var.github_repository}"
  github_aud = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
  other_env  = { dev = "prod", prod = "dev" }
}

resource "aws_iam_role" "github_plan" {
  name                 = "${var.project}-github-plan"
  description          = "terraform plan desde los pull requests (solo lectura)"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = merge(local.github_aud, {
          "token.actions.githubusercontent.com:sub" = "${local.github_sub}:pull_request"
        })
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "github_plan_deny_data" {
  name = "denegar-lectura-de-datos"
  role = aws_iam_role.github_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SinDatosDeNegocio"
        Effect = "Deny"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:BatchGetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "sqs:ReceiveMessage",
          "secretsmanager:GetSecretValue",
        ]
        Resource = "*"
      },
      {
        Sid         = "SoloObjetosDelEstado"
        Effect      = "Deny"
        Action      = "s3:GetObject"
        NotResource = "arn:aws:s3:::${var.project}-tfstate-${local.account_id}/*"
      },
    ]
  })
}

resource "aws_iam_role" "github_deploy" {
  for_each = local.other_env

  name                 = "${var.project}-github-deploy-${each.key}"
  description          = "terraform apply y despliegue de código en ${each.key}"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = merge(local.github_aud, {
          "token.actions.githubusercontent.com:sub" = "${local.github_sub}:environment:${each.key}"
        })
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_deploy_poweruser" {
  for_each = local.other_env

  role       = aws_iam_role.github_deploy[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy" "github_deploy_scope" {
  for_each = local.other_env

  name = "solo-${each.key}"
  role = aws_iam_role.github_deploy[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RolesDelEntorno"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
        ]
        Resource = "arn:aws:iam::${local.account_id}:role/${var.project}-${each.key}-*"
      },
      {
        Sid      = "PasarRolesDelEntornoSoloALambdaYApiGateway"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${local.account_id}:role/${var.project}-${each.key}-*"
        Condition = {
          StringEquals = { "iam:PassedToService" = ["lambda.amazonaws.com", "apigateway.amazonaws.com"] }
        }
      },
      {
        Sid       = "SinRecursosDelOtroEntorno"
        Effect    = "Deny"
        Action    = "*"
        Resource  = "*"
        Condition = { StringEquals = { "aws:ResourceTag/Environment" = each.value } }
      },
      {
        Sid       = "SinCrearRecursosDelOtroEntorno"
        Effect    = "Deny"
        Action    = "*"
        Resource  = "*"
        Condition = { StringEquals = { "aws:RequestTag/Environment" = each.value } }
      },
      {
        Sid    = "SinEstadoNiArtefactosDelOtroEntorno"
        Effect = "Deny"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${var.project}-tfstate-${local.account_id}/${each.value}/*",
          "arn:aws:s3:::${var.project}-artifacts-${local.account_id}/${each.value}/*",
        ]
      },
    ]
  })
}