
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  origin = [{ api_key = [] }]
  auth   = [{ api_key = [], cognito = [] }]

  path_id = [{ name = "id", in = "path", required = true, schema = { type = "string" } }]
  proxy   = [{ name = "proxy", in = "path", required = true, schema = { type = "string" } }]

  lambda = { for k, v in var.integrations : k => {
    type                = "aws_proxy"
    httpMethod          = "POST"
    uri                 = v.invoke_arn
    passthroughBehavior = "when_no_match"
  } }

  signature_attr = var.webhook_signature_header == null ? "" : join("", [
    "#if($input.params('${var.webhook_signature_header}') != \"\")",
    "&MessageAttribute.1.Name=signature",
    "&MessageAttribute.1.Value.DataType=String",
    "&MessageAttribute.1.Value.StringValue=$util.urlEncode($input.params('${var.webhook_signature_header}'))",
    "#end",
  ])
  sqs_template = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)${local.signature_attr}"

  webhook_integration = {
    type                = "aws"
    httpMethod          = "POST"
    uri                 = "arn:aws:apigateway:${local.region}:sqs:path/${local.account_id}/${var.webhook_queue.name}"
    credentials         = aws_iam_role.webhook.arn
    passthroughBehavior = "never"
    requestParameters = {
      "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
    }
    requestTemplates = {
      "application/json"                  = local.sqs_template
      "application/x-www-form-urlencoded" = local.sqs_template
    }
    responses = {
      default = {
        statusCode        = "200"
        responseTemplates = { "application/json" = "{\"received\": true}" }
      }
      "4\\d{2}|5\\d{2}" = {
        statusCode        = "500"
        responseTemplates = { "application/json" = "{\"received\": false}" }
      }
    }
  }

  openapi = {
    openapi                              = "3.0.1"
    info                                 = { title = "${local.name}-api", version = "1.0" }
    "x-amazon-apigateway-api-key-source" = "HEADER"

    paths = {
      "/api/products" = {
        get = { security = local.origin, "x-amazon-apigateway-integration" = local.lambda["catalog"] }
      }
      "/api/products/{id}" = {
        get = { security = local.origin, parameters = local.path_id, "x-amazon-apigateway-integration" = local.lambda["catalog"] }
      }
      "/api/admin/{proxy+}" = {
        "x-amazon-apigateway-any-method" = {
          security                          = local.auth
          parameters                        = local.proxy
          "x-amazon-apigateway-integration" = local.lambda["catalog"]
        }
      }
      "/api/me" = {
        get = { security = local.auth, "x-amazon-apigateway-integration" = local.lambda["users"] }
        put = { security = local.auth, "x-amazon-apigateway-integration" = local.lambda["users"] }
      }
      "/api/orders" = {
        post = { security = local.auth, "x-amazon-apigateway-integration" = local.lambda["orders"] }
      }
      "/api/orders/{id}" = {
        get = { security = local.auth, parameters = local.path_id, "x-amazon-apigateway-integration" = local.lambda["orders"] }
      }
      "/api/payments/webhook" = {
        post = {
          security = local.origin
          responses = {
            "200" = { description = "Encolado" }
            "500" = { description = "No se pudo encolar; la pasarela reintenta" }
          }
          "x-amazon-apigateway-integration" = local.webhook_integration
        }
      }
    }

    components = {
      securitySchemes = {
        api_key = {
          type = "apiKey"
          name = "x-api-key"
          in   = "header"
        }
        cognito = {
          type                           = "apiKey"
          name                           = "Authorization"
          in                             = "header"
          "x-amazon-apigateway-authtype" = "cognito_user_pools"
          "x-amazon-apigateway-authorizer" = {
            type         = "cognito_user_pools"
            providerARNs = [var.user_pool_arn]
          }
        }
      }
    }
  }
}

resource "aws_api_gateway_rest_api" "this" {
  name = "${local.name}-api"
  body = jsonencode(local.openapi)
  tags = var.tags

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode(local.openapi))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${local.name}-api"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_api_gateway_stage" "this" {
  stage_name           = var.stage_name
  rest_api_id          = aws_api_gateway_rest_api.this.id
  deployment_id        = aws_api_gateway_deployment.this.id
  xray_tracing_enabled = true
  tags                 = var.tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      path               = "$context.path"
      status             = "$context.status"
      responseLength     = "$context.responseLength"
      latencyMs          = "$context.responseLatency"
      integrationLatency = "$context.integrationLatency"
      userAgent          = "$context.identity.userAgent"
      xrayTraceId        = "$context.xrayTraceId"
      error              = "$context.error.message"
    })
  }
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
    metrics_enabled        = false
    logging_level          = "OFF"
  }
}

resource "aws_api_gateway_api_key" "cloudfront" {
  name        = "${local.name}-cloudfront"
  description = "La envía CloudFront como cabecera de origen; sin ella la URL execute-api responde 403"
  tags        = var.tags
}

resource "aws_api_gateway_usage_plan" "cloudfront" {
  name = "${local.name}-cloudfront"
  tags = var.tags

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "cloudfront" {
  key_id        = aws_api_gateway_api_key.cloudfront.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.cloudfront.id
}

resource "aws_lambda_permission" "api" {
  for_each = var.integrations

  statement_id  = "PermitirApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  qualifier     = each.value.alias_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*"
}

resource "aws_iam_role" "webhook" {
  name = "${local.name}-api-webhook"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "webhook" {
  name = "solo-cola-del-webhook"
  role = aws_iam_role.webhook.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EncolarWebhook"
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = var.webhook_queue.arn
      },
      {
        Sid      = "CifrarMensaje"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = var.kms_key_arn
      },
    ]
  })
}
