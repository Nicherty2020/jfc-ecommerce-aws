mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }

  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/jfc-dev-api-webhook" }
  }
  mock_resource "aws_api_gateway_rest_api" {
    defaults = {
      id            = "abc123"
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:abc123"
    }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/apigateway/jfc-dev-api" }
  }
}

variables {
  project       = "jfc"
  environment   = "dev"
  user_pool_arn = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_example"
  kms_key_arn   = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"

  integrations = {
    for s in ["catalog", "users", "orders"] : s => {
      function_name = "jfc-dev-${s}"
      alias_name    = "live"
      invoke_arn    = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:jfc-dev-${s}:live/invocations"
    }
  }

  webhook_queue = {
    name = "jfc-dev-payments-webhook"
    arn  = "arn:aws:sqs:us-east-1:123456789012:jfc-dev-payments-webhook"
  }
}

run "origen_cerrado_y_rutas_privadas" {
  command = apply

  assert {
    condition = alltrue(flatten([
      for path, methods in jsondecode(aws_api_gateway_rest_api.this.body).paths : [
        for method, op in methods : anytrue([for s in op.security : contains(keys(s), "api_key")])
      ]
    ]))
    error_message = "Todas las rutas deben exigir la API key que envía CloudFront (D10)."
  }

  assert {
    condition = alltrue([
      for route in [["/api/me", "get"], ["/api/me", "put"], ["/api/orders", "post"], ["/api/orders/{id}", "get"], ["/api/admin/{proxy+}", "x-amazon-apigateway-any-method"]] :
      contains(keys(jsondecode(aws_api_gateway_rest_api.this.body).paths[route[0]][route[1]].security[0]), "cognito")
    ])
    error_message = "Las rutas privadas deben exigir el JWT de Cognito."
  }

  assert {
    condition = alltrue([
      for route in [["/api/products", "get"], ["/api/products/{id}", "get"], ["/api/payments/webhook", "post"]] :
      !contains(keys(jsondecode(aws_api_gateway_rest_api.this.body).paths[route[0]][route[1]].security[0]), "cognito")
    ])
    error_message = "El catálogo y el webhook son públicos (sin JWT)."
  }

  assert {
    condition     = one(aws_api_gateway_usage_plan.cloudfront.api_stages).stage == "v1"
    error_message = "El plan de uso debe cubrir el stage v1."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.webhook.policy).Statement[0].Resource == var.webhook_queue.arn
    error_message = "API Gateway solo puede escribir en la cola del webhook."
  }
}
