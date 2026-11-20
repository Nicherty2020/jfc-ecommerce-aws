locals {
  subscribed_queues = { for k, q in var.queues : k => q if length(q.event_types) > 0 }
}

resource "aws_sqs_queue" "dlq" {
  for_each = var.queues

  name                              = "${local.name}-${each.key}-dlq"
  message_retention_seconds         = 14 * 24 * 3600
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300
  tags                              = var.tags
}

resource "aws_sqs_queue" "this" {
  for_each = var.queues

  name                              = "${local.name}-${each.key}"
  visibility_timeout_seconds        = var.timeout * 6
  message_retention_seconds         = 4 * 24 * 3600
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300
  tags                              = var.tags

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = each.value.max_receive_count
  })
}

resource "aws_cloudwatch_event_rule" "this" {
  for_each = local.subscribed_queues

  name           = "${local.name}-${each.key}"
  description    = "Eventos que consume ${var.service}: ${join(", ", each.value.event_types)}"
  event_bus_name = var.event_bus_name
  tags           = var.tags

  event_pattern = jsonencode({
    "detail-type" = each.value.event_types
  })
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = local.subscribed_queues

  rule           = aws_cloudwatch_event_rule.this[each.key].name
  event_bus_name = var.event_bus_name
  target_id      = "sqs"
  arn            = aws_sqs_queue.this[each.key].arn

  dead_letter_config {
    arn = aws_sqs_queue.dlq[each.key].arn
  }
}

resource "aws_sqs_queue_policy" "this" {
  for_each = local.subscribed_queues

  queue_url = aws_sqs_queue.this[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "SoloDesdeSuRegla"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.this[each.key].arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.this[each.key].arn } }
    }]
  })
}

resource "aws_sqs_queue_policy" "dlq" {
  for_each = local.subscribed_queues

  queue_url = aws_sqs_queue.dlq[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EntregasFallidasDeSuRegla"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.dlq[each.key].arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.this[each.key].arn } }
    }]
  })
}

resource "aws_lambda_event_source_mapping" "this" {
  for_each = var.queues

  event_source_arn        = aws_sqs_queue.this[each.key].arn
  function_name           = aws_lambda_alias.live.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]

  dynamic "scaling_config" {
    for_each = each.value.max_concurrency != null ? [1] : []
    content {
      maximum_concurrency = each.value.max_concurrency
    }
  }

  depends_on = [aws_iam_role_policy.this]
}
