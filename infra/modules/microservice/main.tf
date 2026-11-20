locals {
  name        = "${var.project}-${var.environment}-${var.service}"
  is_python   = startswith(var.runtime, "python")
  handler_mod = split(".", var.handler)[0]
  handler_fn  = split(".", var.handler)[1]

  placeholder_file = local.is_python ? "${local.handler_mod}.py" : "${local.handler_mod}.mjs"
  placeholder_code = local.is_python ? join("\n", [
    "def ${local.handler_fn}(event, context):",
    "    return {\"statusCode\": 503, \"body\": \"Servicio aún no desplegado\"}",
    ]) : join("\n", [
    "export const ${local.handler_fn} = async () => ({ statusCode: 503, body: 'Servicio aún no desplegado' });",
  ])

  env_vars = merge(
    {
      ENVIRONMENT                  = var.environment
      POWERTOOLS_SERVICE_NAME      = var.service
      POWERTOOLS_METRICS_NAMESPACE = "${var.project}-${var.environment}"
      LOG_LEVEL                    = var.environment == "prod" ? "INFO" : "DEBUG"
    },
    var.create_table ? { TABLE_NAME = aws_dynamodb_table.this[0].name } : {},
    var.publishes_events ? { EVENT_BUS_NAME = var.event_bus_name } : {},
    var.environment_variables,
  )
}

data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.root}/.build/${local.name}.zip"

  source {
    filename = local.placeholder_file
    content  = local.placeholder_code
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  function_name                  = local.name
  role                           = aws_iam_role.this.arn
  runtime                        = var.runtime
  handler                        = var.handler
  architectures                  = ["arm64"]
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrency
  layers                         = var.layers
  filename                       = data.archive_file.placeholder.output_path
  source_code_hash               = data.archive_file.placeholder.output_base64sha256
  publish                        = true
  tags                           = var.tags

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = local.env_vars
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash, s3_bucket, s3_key, s3_object_version]
  }

  depends_on = [aws_cloudwatch_log_group.this, aws_iam_role_policy.this]
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Versión en servicio; la mueve el pipeline"
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version

  lifecycle {
    ignore_changes = [function_version]
  }
}

resource "aws_cloudwatch_event_rule" "schedule" {
  count = var.schedule_expression != null ? 1 : 0

  name                = "${local.name}-schedule"
  description         = "Ejecución programada de ${local.name}"
  schedule_expression = var.schedule_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "schedule" {
  count = var.schedule_expression != null ? 1 : 0

  rule      = aws_cloudwatch_event_rule.schedule[0].name
  target_id = "lambda"
  arn       = aws_lambda_alias.live.arn
}

resource "aws_lambda_permission" "schedule" {
  count = var.schedule_expression != null ? 1 : 0

  statement_id  = "PermitirEventBridgeProgramado"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  qualifier     = aws_lambda_alias.live.name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule[0].arn
}
