mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_resource "aws_cloudfront_function" {
    defaults = {
      arn = "arn:aws:cloudfront::123456789012:function/jfc-spa-rewrite"
    }
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
    defaults = {
      certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn            = "arn:aws:cloudfront::123456789012:distribution/EDFDVBD6EXAMPLE"
      domain_name    = "d111111abcdef8.cloudfront.net"
      hosted_zone_id = "Z2FDTNDATAQYW2"
    }
  }

  mock_resource "aws_wafv2_web_acl" {
    defaults = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/jfc-prod-edge/00000000-0000-0000-0000-000000000000"
    }
  }
}

run "solo_frontend" {
  command = apply

  variables {
    environment = "dev"
    enable_waf  = false
  }

  assert {
    condition     = aws_s3_bucket.frontend.bucket == "jfc-dev-frontend-123456789012"
    error_message = "El nombre del bucket no sigue la convención proyecto-entorno-frontend-cuenta."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.frontend.block_public_acls,
      aws_s3_bucket_public_access_block.frontend.block_public_policy,
      aws_s3_bucket_public_access_block.frontend.ignore_public_acls,
      aws_s3_bucket_public_access_block.frontend.restrict_public_buckets,
    ])
    error_message = "Block Public Access debe estar activo en sus 4 opciones."
  }

  assert {
    condition     = aws_s3_bucket_versioning.frontend.versioning_configuration[0].status == "Enabled"
    error_message = "El versionado del bucket debe estar activo."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.price_class == "PriceClass_All"
    error_message = "La clase de precio debe ser All (incluye Sudamérica)."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "El frontend debe redirigir HTTP a HTTPS."
  }

  assert {
    condition     = length(aws_cloudfront_distribution.this.ordered_cache_behavior) == 0
    error_message = "Sin API no deben existir comportamientos /api/*."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.web_acl_id == null
    error_message = "Con enable_waf = false no debe asociarse un WAF."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].cloudfront_default_certificate == true
    error_message = "Sin dominio propio se debe usar el certificado *.cloudfront.net."
  }

  assert {
    condition     = aws_cloudfront_origin_access_control.frontend.signing_behavior == "always"
    error_message = "OAC debe firmar siempre las peticiones a S3."
  }
}

run "frontend_api_waf_y_plan_free" {
  command = apply

  variables {
    environment       = "prod"
    enable_waf        = true
    pricing_plan_tier = "FREE"
    api_origin_domain = "abc123.execute-api.us-east-1.amazonaws.com"
    api_origin_path   = "/v1"
    api_origin_key    = "clave-de-prueba"
  }

  assert {
    condition     = length(aws_cloudfront_distribution.this.origin) == 2
    error_message = "Deben existir dos orígenes: S3 y API Gateway."
  }

  assert {
    condition = nonsensitive(anytrue([
      for o in aws_cloudfront_distribution.this.origin :
      o.origin_id == "api-gateway" && contains([for h in o.custom_header : h.name], "x-api-key")
    ]))
    error_message = "CloudFront debe enviar la x-api-key al origen de la API (D10)."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[0].path_pattern == "/api/products*"
    error_message = "El catálogo debe evaluarse antes que /api/*."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[0].cache_policy_id == data.aws_cloudfront_cache_policy.caching_optimized.id
    error_message = "El catálogo debe usar CachingOptimized: el TTL lo fija el max-age del origen (S11)."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[1].path_pattern == "/api/*"
    error_message = "Debe existir el comportamiento /api/* sin caché."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[1].cache_policy_id == data.aws_cloudfront_cache_policy.caching_disabled.id
    error_message = "Las rutas privadas del API no deben cachearse."
  }

  assert {
    condition     = aws_wafv2_web_acl.this[0].scope == "CLOUDFRONT"
    error_message = "El WAF debe tener scope CLOUDFRONT."
  }

  assert {
    condition     = length(aws_wafv2_web_acl.this[0].rule) == 5
    error_message = "El WAF debe tener 4 grupos administrados + 1 regla de tasa."
  }

  assert {
    condition = one([
      for r in aws_wafv2_web_acl.this[0].rule : r if r.name == "limite-tasa-por-ip"
    ]).statement[0].rate_based_statement[0].scope_down_statement[0].not_statement[0].statement[0].byte_match_statement[0].search_string == "/api/payments/webhook"
    error_message = "La regla de tasa debe excluir el webhook de la pasarela."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.web_acl_id == aws_wafv2_web_acl.this[0].arn
    error_message = "La distribución debe estar asociada al WAF."
  }

  assert {
    condition = (
      aws_pricingplanmanager_subscription.this[0].plan_tier == "FREE" &&
      aws_pricingplanmanager_subscription.this[0].resource_arns == toset([aws_cloudfront_distribution.this.arn, aws_wafv2_web_acl.this[0].arn])
    )
    error_message = "El plan Free debe cubrir la distribución y su WAF (D11)."
  }

  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.frontend.policy).Statement[0].Condition.StringEquals["AWS:SourceArn"]
      == aws_cloudfront_distribution.this.arn
    )
    error_message = "El bucket solo debe permitir lectura a ESTA distribución (AWS:SourceArn)."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.frontend.policy).Statement[1].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "La política debe negar las peticiones sin TLS."
  }
}

run "con_dominio_propio" {
  command = apply

  variables {
    environment    = "prod"
    domain_name    = "tienda.example.com"
    hosted_zone_id = "Z0123456789ABCDEFGHIJ"
  }

  assert {
    condition     = aws_acm_certificate.this[0].validation_method == "DNS"
    error_message = "El certificado debe validarse por DNS."
  }

  assert {
    condition     = contains(aws_cloudfront_distribution.this.aliases, "tienda.example.com")
    error_message = "La distribución debe responder en el dominio propio."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.viewer_certificate[0].minimum_protocol_version == "TLSv1.2_2021"
    error_message = "Con dominio propio, el mínimo debe ser TLS 1.2."
  }

  assert {
    condition     = length(aws_route53_record.alias) == 2
    error_message = "Deben existir los alias A y AAAA hacia CloudFront."
  }
}

run "api_sin_api_key_falla" {
  command = plan

  variables {
    environment       = "dev"
    api_origin_domain = "abc123.execute-api.us-east-1.amazonaws.com"
  }

  expect_failures = [var.api_origin_key]
}

run "plan_sin_waf_falla" {
  command = plan

  variables {
    environment       = "dev"
    enable_waf        = false
    pricing_plan_tier = "FREE"
  }

  expect_failures = [var.pricing_plan_tier]
}

run "dominio_sin_zona_falla" {
  command = plan

  variables {
    environment = "dev"
    domain_name = "tienda.example.com"
  }

  expect_failures = [var.hosted_zone_id]
}

run "entorno_invalido_falla" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}
