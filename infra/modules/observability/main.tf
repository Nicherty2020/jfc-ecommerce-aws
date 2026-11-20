data "aws_region" "current" {}

locals {
  name   = "${var.project}-${var.environment}"
  region = data.aws_region.current.region
  api    = ["ApiName", var.api_name, "Stage", var.api_stage]

  widgets = [
    {
      title = "API: peticiones y errores"
      metrics = [
        concat(["AWS/ApiGateway", "Count"], local.api, [{ stat = "Sum", label = "Peticiones" }]),
        concat(["AWS/ApiGateway", "4XXError"], local.api, [{ stat = "Sum", label = "4XX" }]),
        concat(["AWS/ApiGateway", "5XXError"], local.api, [{ stat = "Sum", label = "5XX" }]),
      ]
    },
    {
      title = "API: latencia p95 (ms)"
      metrics = [
        concat(["AWS/ApiGateway", "Latency"], local.api, [{ stat = "p95", label = "Total" }]),
        concat(["AWS/ApiGateway", "IntegrationLatency"], local.api, [{ stat = "p95", label = "Backend" }]),
      ]
    },
    {
      title   = "Lambda: invocaciones"
      metrics = [for f in var.function_names : ["AWS/Lambda", "Invocations", "FunctionName", f, { stat = "Sum" }]]
    },
    {
      title = "Lambda: errores y throttles"
      metrics = concat(
        [for f in var.function_names : ["AWS/Lambda", "Errors", "FunctionName", f, { stat = "Sum" }]],
        [for f in var.function_names : ["AWS/Lambda", "Throttles", "FunctionName", f, { stat = "Sum" }]],
      )
    },
    {
      title   = "Lambda: duración p95 (ms)"
      metrics = [for f in var.function_names : ["AWS/Lambda", "Duration", "FunctionName", f, { stat = "p95" }]]
    },
    {
      title = "Lambda: concurrencia"
      metrics = concat(
        [for f in var.function_names : ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", f, { stat = "Maximum" }]],
        [["AWS/Lambda", "ClaimedAccountConcurrency", { stat = "Maximum", label = "Cuenta (dev + prod)" }]],
      )
    },
    {
      title = "DynamoDB: capacidad consumida"
      metrics = concat(
        [for t in var.table_names : ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", t, { stat = "Sum" }]],
        [for t in var.table_names : ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", t, { stat = "Sum" }]],
      )
    },
    {
      title = "DynamoDB: eventos limitados"
      metrics = concat(
        [for t in var.table_names : ["AWS/DynamoDB", "ReadThrottleEvents", "TableName", t, { stat = "Sum" }]],
        [for t in var.table_names : ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", t, { stat = "Sum" }]],
      )
    },
    {
      title   = "Colas: mensajes pendientes"
      metrics = [for q in var.queue_names : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", q, { stat = "Maximum" }]]
    },
    {
      title   = "Colas: edad del mensaje más antiguo (s)"
      metrics = [for q in var.queue_names : ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", q, { stat = "Maximum" }]]
    },
    {
      title   = "DLQ: mensajes (debe ser 0)"
      metrics = [for q in var.dlq_names : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", q, { stat = "Maximum" }]]
    },
    {
      title = "Pedidos"
      metrics = [for m in ["OrderCreated", "OrderConfirmed", "OrderCancelled", "PaymentNeedsRefund"] :
        ["${var.project}-${var.environment}", m, "service", "orders", { stat = "Sum" }]
      ]
    },
  ]
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name}-api-5xx"
  alarm_description   = "Más del ${var.api_5xx_rate_threshold * 100} % de respuestas 5XX en 5 minutos"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  dimensions          = { ApiName = var.api_name, Stage = var.api_stage }
  statistic           = "Average" # en API REST, el promedio de 5XXError es la tasa de error
  period              = 300
  evaluation_periods  = 1
  threshold           = var.api_5xx_rate_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "payment_needs_refund" {
  alarm_name          = "${local.name}-pago-tras-cancelacion"
  alarm_description   = "Llegó un pago para un pedido ya cancelado (PaymentNeedsRefund): gestionar el reembolso manual."
  namespace           = "${var.project}-${var.environment}"
  metric_name         = "PaymentNeedsRefund"
  dimensions          = { service = "orders" }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  tags                = var.tags
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = local.name

  dashboard_body = jsonencode({
    widgets = [for i, w in local.widgets : {
      type   = "metric"
      x      = (i % 2) * 12
      y      = floor(i / 2) * 6
      width  = 12
      height = 6
      properties = {
        title   = w.title
        region  = local.region
        view    = "timeSeries"
        stacked = false
        period  = 300
        metrics = w.metrics
      }
    }]
  })
}
