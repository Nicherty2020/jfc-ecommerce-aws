locals {
  s3_origin_id  = "s3-frontend"
  api_origin_id = "api-gateway"
  has_api       = var.api_origin_domain != null
  has_domain    = length(var.aliases) > 0
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# Reenvía todo menos Host: API Gateway necesita su propio Host.
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name}-frontend-oac"
  description                       = "Acceso de CloudFront al bucket del frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "catalog" {
  count = local.has_api ? 1 : 0

  name        = "${local.name}-catalog"
  comment     = "Lecturas públicas del catálogo"
  min_ttl     = 0
  default_ttl = var.catalog_cache_default_ttl
  max_ttl     = var.catalog_cache_max_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_function" "spa_rewrite" {
  name    = "${local.name}-spa-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Sirve index.html para las rutas de la SPA"
  publish = true
  code    = file("${path.module}/functions/spa-rewrite.js")
}

resource "aws_cloudfront_distribution" "this" {
  #checkov:skip=CKV_AWS_174:Sin dominio propio se usa *.cloudfront.net; con dominio se fija TLSv1.2_2021
  #checkov:skip=CKV_AWS_86:Logs de acceso desactivados por costo
  #checkov:skip=CKV_AWS_374:Sin restricción geográfica; el WAF filtra por reputación y tasa
  #checkov:skip=CKV_AWS_310:Failover de origen fuera del alcance de la v1
  #checkov:skip=CKV2_AWS_47:KnownBadInputsRuleSet (Log4j) está en waf.tf
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  comment             = "${local.name} e-commerce"
  default_root_object = "index.html"
  price_class         = var.price_class
  aliases             = var.aliases
  web_acl_id          = var.enable_waf ? aws_wafv2_web_acl.this[0].arn : null

  origin {
    origin_id                = local.s3_origin_id
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  dynamic "origin" {
    for_each = local.has_api ? [1] : []
    content {
      origin_id   = local.api_origin_id
      domain_name = var.api_origin_domain
      origin_path = var.api_origin_path

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior {
    target_origin_id           = local.s3_origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite.arn
    }
  }

  # El orden importa: /api/products* tiene que ir antes que /api/*.
  dynamic "ordered_cache_behavior" {
    for_each = local.has_api ? [1] : []
    content {
      path_pattern               = "/api/products*"
      target_origin_id           = local.api_origin_id
      viewer_protocol_policy     = "https-only"
      allowed_methods            = ["GET", "HEAD", "OPTIONS"]
      cached_methods             = ["GET", "HEAD"]
      compress                   = true
      cache_policy_id            = aws_cloudfront_cache_policy.catalog[0].id
      response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.has_api ? [1] : []
    content {
      path_pattern               = "/api/*"
      target_origin_id           = local.api_origin_id
      viewer_protocol_policy     = "https-only"
      allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods             = ["GET", "HEAD"]
      compress                   = true
      cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
      origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
      response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = local.has_domain ? null : true
    acm_certificate_arn            = local.has_domain ? var.acm_certificate_arn : null
    ssl_support_method             = local.has_domain ? "sni-only" : null
    minimum_protocol_version       = local.has_domain ? "TLSv1.2_2021" : null
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = !local.has_domain || var.acm_certificate_arn != null
      error_message = "Si defines aliases, también debes definir acm_certificate_arn (en us-east-1)."
    }
  }
}
