locals {
  table_read_actions = [
    "dynamodb:GetItem",
    "dynamodb:BatchGetItem",
    "dynamodb:Query",
    "dynamodb:DescribeTable",
  ]
  table_write_actions = [
    "dynamodb:PutItem",
    "dynamodb:UpdateItem",
    "dynamodb:DeleteItem",
    "dynamodb:ConditionCheckItem",
  ]

  policy_statements = concat(
    [
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.this.arn}:*"
      },
      {
        Sid      = "Trazas"
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      },
      {
        Sid      = "LlaveDeDatos"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      },
    ],
    var.create_table ? [{
      Sid    = "TablaPropia"
      Effect = "Allow"
      Action = var.table_access == "read" ? local.table_read_actions : concat(local.table_read_actions, local.table_write_actions)
      Resource = [
        aws_dynamodb_table.this[0].arn,
        "${aws_dynamodb_table.this[0].arn}/index/*",
      ]
    }] : [],
    var.publishes_events ? [{
      Sid      = "PublicarEventos"
      Effect   = "Allow"
      Action   = "events:PutEvents"
      Resource = var.event_bus_arn
    }] : [],
    length(var.queues) > 0 ? [{
      Sid    = "ConsumirColasPropias"
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueAttributes",
      ]
      Resource = [for q in aws_sqs_queue.this : q.arn]
    }] : [],
    [for s in var.extra_policy_statements : merge(
      {
        Sid      = s.sid
        Effect   = "Allow"
        Action   = s.actions
        Resource = s.resources
      },
      s.condition != null ? { Condition = s.condition } : {},
    )],
  )
}

resource "aws_iam_role" "this" {
  name = "${local.name}-lambda"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "minimo-privilegio"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.policy_statements
  })
}
