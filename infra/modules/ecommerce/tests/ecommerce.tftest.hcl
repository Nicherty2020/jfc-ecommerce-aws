mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
  mock_data "aws_route53_zone" {
    defaults = { zone_id = "Z0123456789ABCDEFGHIJ" }
  }

  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000" }
  }
  mock_resource "aws_cloudwatch_event_bus" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:event-bus/jfc-ecommerce" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:us-east-1:123456789012:jfc-alarms" }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:jfc/payments/gateway-AbCdEf" }
  }
  mock_resource "aws_cognito_user_pool" {
    defaults = {
      id  = "us-east-1_example"
      arn = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_example"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/jfc-role" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:function:jfc-fn", version = "1" }
  }
  mock_resource "aws_lambda_alias" {
    defaults = {
      arn        = "arn:aws:lambda:us-east-1:123456789012:function:jfc-fn:live"
      invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:jfc-fn:live/invocations"
    }
  }
  mock_resource "aws_sqs_queue" {
    defaults = { arn = "arn:aws:sqs:us-east-1:123456789012:jfc-queue" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:rule/jfc-rule" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:jfc" }
  }
  mock_resource "aws_dynamodb_table" {
    defaults = { arn = "arn:aws:dynamodb:us-east-1:123456789012:table/jfc-table" }
  }
  mock_resource "aws_api_gateway_rest_api" {
    defaults = {
      id            = "abc123"
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:abc123"
    }
  }
  mock_resource "aws_cloudfront_function" {
    defaults = { arn = "arn:aws:cloudfront::123456789012:function/jfc-spa-rewrite" }
  }
  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn            = "arn:aws:cloudfront::123456789012:distribution/EDFDVBD6EXAMPLE"
      domain_name    = "d111111abcdef8.cloudfront.net"
      hosted_zone_id = "Z2FDTNDATAQYW2"
    }
  }
  mock_resource "aws_wafv2_web_acl" {
    defaults = { arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/jfc-edge/0000" }
  }
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
      domain_validation_options = [{
        domain_name           = "tienda.example.com"
        resource_record_name  = "_abc.tienda.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_xyz.acm-validations.aws."
      }]
    }
  }
  mock_resource "aws_acm_certificate_validation" {
    defaults = { certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000" }
  }
}

mock_provider "archive" {}

variables {
  alarm_email      = "alertas@example.com"
  ses_identity     = "notificaciones@example.com"
  ses_from_address = "notificaciones@example.com"
}

run "entorno_dev" {
  command = apply

  variables {
    environment                 = "dev"
    deletion_protection         = false
    force_destroy_bucket        = true
    log_retention_days          = 14
    kms_deletion_window_days    = 7
    secret_recovery_window_days = 0
  }

  assert {
    condition     = length(output.lambda_functions) == 6
    error_message = "Deben existir las 6 funciones (5 servicios + notificaciones)."
  }

  assert {
    condition     = output.lambda_functions["orders"] == "jfc-dev-orders"
    error_message = "Los nombres deben seguir proyecto-entorno-servicio."
  }

  assert {
    condition     = module.api.origin_path == "/v1" && module.api.origin_domain == "abc123.execute-api.us-east-1.amazonaws.com"
    error_message = "CloudFront debe apuntar al stage v1 de la API."
  }

  assert {
    condition     = keys(module.payments.queues) == ["events", "webhook"]
    error_message = "Pagos debe tener la cola de eventos y la del webhook."
  }

  assert {
    condition     = aws_secretsmanager_secret.payments_gateway.kms_key_id == module.platform.kms_key_arn
    error_message = "El secreto de la pasarela debe cifrarse con la CMK."
  }

  assert {
    condition     = startswith(output.site_url, "https://d111111abcdef8.cloudfront.net")
    error_message = "Sin dominio propio el sitio se sirve en *.cloudfront.net."
  }

  assert {
    condition     = output.api_execute_url == "https://abc123.execute-api.us-east-1.amazonaws.com/v1"
    error_message = "La prueba de humo necesita la URL directa de la API."
  }
}

run "entorno_prod_con_dominio" {
  command = apply

  variables {
    environment           = "prod"
    domain_name           = "tienda.example.com"
    hosted_zone_name      = "example.com"
    cognito_email_via_ses = true
    reserved_concurrency  = { orders = 100, inventory = 50 }
    sqs_max_concurrency   = { orders = 50, inventory = 40 }
  }

  assert {
    condition     = output.site_url == "https://tienda.example.com"
    error_message = "Con dominio propio el sitio se sirve en ese dominio."
  }
}

run "dominio_sin_zona_falla" {
  command = plan

  variables {
    environment = "dev"
    domain_name = "tienda.example.com"
  }

  expect_failures = [var.hosted_zone_name]
}
