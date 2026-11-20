mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/jfc-dev-orders-lambda" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:function:jfc-dev-orders", version = "1" }
  }
  mock_resource "aws_lambda_alias" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:function:jfc-dev-orders:live" }
  }
  mock_resource "aws_sqs_queue" {
    defaults = { arn = "arn:aws:sqs:us-east-1:123456789012:jfc-dev-orders-events" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:rule/jfc-dev-ecommerce/jfc-dev-orders-events" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/lambda/jfc-dev-orders" }
  }
  mock_resource "aws_dynamodb_table" {
    defaults = { arn = "arn:aws:dynamodb:us-east-1:123456789012:table/jfc-dev-orders" }
  }
}

variables {
  project         = "jfc"
  environment     = "dev"
  service         = "orders"
  kms_key_arn     = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  alarm_topic_arn = "arn:aws:sns:us-east-1:123456789012:jfc-dev-alarms"
  event_bus_name  = "jfc-dev-ecommerce"
  event_bus_arn   = "arn:aws:events:us-east-1:123456789012:event-bus/jfc-dev-ecommerce"
}

run "servicio_del_checkout" {
  command = apply

  variables {
    publishes_events     = true
    alarm_on_any_error   = true
    reserved_concurrency = 100
    schedule_expression  = "rate(5 minutes)"
    queues = {
      events = {
        event_types     = ["StockRejected", "PaymentApproved"]
        max_concurrency = 50
      }
    }
  }

  assert {
    condition     = aws_lambda_function.this.architectures[0] == "arm64" && aws_lambda_function.this.tracing_config[0].mode == "Active"
    error_message = "La función debe ser arm64 y con X-Ray activo."
  }

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == 100
    error_message = "La concurrencia reservada no se aplicó."
  }

  assert {
    condition = (
      aws_dynamodb_table.this[0].billing_mode == "PAY_PER_REQUEST" &&
      aws_dynamodb_table.this[0].point_in_time_recovery[0].enabled &&
      aws_dynamodb_table.this[0].deletion_protection_enabled &&
      aws_dynamodb_table.this[0].server_side_encryption[0].kms_key_arn == var.kms_key_arn &&
      aws_dynamodb_table.this[0].ttl[0].enabled
    )
    error_message = "La tabla debe ser on-demand, con PITR, protección contra borrado, CMK y TTL."
  }

  assert {
    condition     = jsondecode(aws_sqs_queue.this["events"].redrive_policy).maxReceiveCount == 5
    error_message = "La cola debe enviar a su DLQ tras 5 intentos."
  }

  assert {
    condition     = aws_sqs_queue.this["events"].kms_master_key_id == var.kms_key_arn && aws_sqs_queue.dlq["events"].kms_master_key_id == var.kms_key_arn
    error_message = "La cola y su DLQ deben cifrarse con la CMK."
  }

  assert {
    condition     = aws_sqs_queue.this["events"].visibility_timeout_seconds == 60
    error_message = "El visibility timeout debe ser 6 veces el timeout de la función."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.this["events"].event_pattern)["detail-type"] == ["StockRejected", "PaymentApproved"]
    error_message = "La regla debe filtrar solo los eventos que consume el servicio."
  }

  assert {
    condition     = aws_cloudwatch_event_target.this["events"].dead_letter_config[0].arn == aws_sqs_queue.dlq["events"].arn
    error_message = "Las entregas fallidas de EventBridge deben ir a la DLQ."
  }

  assert {
    condition     = jsondecode(aws_sqs_queue_policy.this["events"].policy).Statement[0].Condition.ArnEquals["aws:SourceArn"] == aws_cloudwatch_event_rule.this["events"].arn
    error_message = "Solo la regla del servicio puede escribir en su cola."
  }

  assert {
    condition     = aws_lambda_event_source_mapping.this["events"].function_response_types == toset(["ReportBatchItemFailures"])
    error_message = "La lectura de la cola debe reportar fallas por mensaje."
  }

  assert {
    condition     = aws_lambda_event_source_mapping.this["events"].scaling_config[0].maximum_concurrency == 50
    error_message = "El tope de concurrencia de la cola no se aplicó."
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.schedule) == 1 && aws_lambda_permission.schedule[0].qualifier == "live"
    error_message = "La ejecución programada debe invocar el alias live."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.errors) == 1 && length(aws_cloudwatch_metric_alarm.dlq) == 1 && length(aws_cloudwatch_metric_alarm.queue_age) == 1
    error_message = "Faltan alarmas del checkout (errores, DLQ o atraso)."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.this.policy).Statement :
      s.Sid == "Trazas" || !contains(flatten([s.Resource]), "*")
    ])
    error_message = "Solo X-Ray puede usar Resource \"*\"."
  }

  assert {
    condition     = contains([for s in jsondecode(aws_iam_role_policy.this.policy).Statement : s.Sid], "PublicarEventos")
    error_message = "Un servicio que publica eventos necesita events:PutEvents sobre el bus."
  }
}

run "servicio_de_solo_lectura_sin_eventos" {
  command = apply

  variables {
    service             = "catalog"
    table_access        = "read"
    deletion_protection = false
  }

  assert {
    condition     = length(aws_sqs_queue.this) == 0 && length(aws_cloudwatch_event_rule.this) == 0
    error_message = "Un servicio sin colas no debe crear colas ni reglas."
  }

  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.this.policy).Statement :
      [for a in flatten([s.Action]) : !contains(["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "events:PutEvents"], a)]
    ]))
    error_message = "Un servicio de solo lectura no debe poder escribir ni publicar."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.errors) == 0 && aws_cloudwatch_metric_alarm.throttles.metric_name == "Throttles"
    error_message = "Fuera del checkout solo se alarma por throttles."
  }
}

run "servicio_sin_tabla" {
  command = apply

  variables {
    service      = "notifications"
    create_table = false
    queues       = { events = { event_types = ["OrderConfirmed"] } }
  }

  assert {
    condition     = length(aws_dynamodb_table.this) == 0 && !contains(keys(aws_lambda_function.this.environment[0].variables), "TABLE_NAME")
    error_message = "Sin tabla no debe crearse la tabla ni su variable de entorno."
  }
}

run "nombre_de_servicio_invalido_falla" {
  command = plan

  variables {
    service = "Pedidos_V2"
  }

  expect_failures = [var.service]
}
