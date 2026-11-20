mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  # El provider valida que function_arn tenga formato de ARN.
  mock_resource "aws_cloudfront_function" {
    defaults = {
      arn = "arn:aws:cloudfront::123456789012:function/jfc-spa-rewrite"
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

run "frontend_api_y_waf" {
  command = apply

  variables {
    environment       = "prod"
    enable_waf        = true
    api_origin_domain = "abc123.execute-api.us-east-1.amazonaws.com"
    api_origin_path   = "/v1"
  }

  assert {
    condition     = length(aws_cloudfront_distribution.this.origin) == 2
    error_message = "Deben existir dos orígenes: S3 y API Gateway."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[0].path_pattern == "/api/products*"
    error_message = "El catálogo debe evaluarse antes que /api/*."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[0].cache_policy_id == aws_cloudfront_cache_policy.catalog[0].id
    error_message = "El catálogo debe usar su política de caché propia."
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
    condition     = aws_cloudfront_cache_policy.catalog[0].default_ttl == 60 && aws_cloudfront_cache_policy.catalog[0].max_ttl == 300
    error_message = "El TTL del catálogo debe estar entre 1 y 5 minutos."
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
    condition     = aws_cloudfront_distribution.this.web_acl_id == aws_wafv2_web_acl.this[0].arn
    error_message = "La distribución debe estar asociada al WAF."
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

run "dominio_sin_certificado_falla" {
  command = plan

  variables {
    environment = "dev"
    aliases     = ["tienda.example.com"]
  }

  expect_failures = [aws_cloudfront_distribution.this]
}

run "entorno_invalido_falla" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}
