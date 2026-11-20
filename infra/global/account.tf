resource "aws_iam_role" "apigateway_cloudwatch" {
  name = "${var.project}-apigateway-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apigateway_cloudwatch" {
  role       = aws_iam_role.apigateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.apigateway_cloudwatch.arn

  depends_on = [aws_iam_role_policy_attachment.apigateway_cloudwatch]
}

module "artifacts_bucket" {
  source = "../modules/private-bucket"

  name            = "${var.project}-artifacts-${local.account_id}"
  versioning      = false
  expiration_days = var.artifacts_retention_days
}

resource "aws_sns_topic" "account_alerts" {
  name = "${var.project}-account-alerts"
}

resource "aws_sns_topic_subscription" "account_alerts_email" {
  topic_arn = aws_sns_topic.account_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_concurrency" {
  alarm_name          = "${var.project}-lambda-concurrencia-cuenta"
  alarm_description   = "La concurrencia de Lambda supera el 80 % de la cuota de la cuenta. Pedir aumento en Service Quotas."
  namespace           = "AWS/Lambda"
  metric_name         = "ClaimedAccountConcurrency"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = floor(var.lambda_concurrency_quota * 0.8)
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.account_alerts.arn]
  ok_actions          = [aws_sns_topic.account_alerts.arn]
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-mensual"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = [80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.alert_email]
    }
  }
}
