# scope CLOUDFRONT: el Web ACL tiene que crearse en us-east-1.
locals {
  managed_rule_groups = {
    AWSManagedRulesCommonRuleSet          = 10
    AWSManagedRulesKnownBadInputsRuleSet  = 20
    AWSManagedRulesSQLiRuleSet            = 30
    AWSManagedRulesAmazonIpReputationList = 40
  }
}

resource "aws_wafv2_web_acl" "this" {
  #checkov:skip=CKV_AWS_192:KnownBadInputsRuleSet (Log4j) se agrega en el bloque dynamic
  #checkov:skip=CKV2_AWS_31:Logs del WAF desactivados por costo
  count = var.enable_waf ? 1 : 0

  name        = "${local.name}-edge"
  description = "WAF del borde del e-commerce"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "limite-tasa-por-ip"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = var.waf_rate_limit
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = local.managed_rule_groups
    content {
      name     = rule.key
      priority = rule.value

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = rule.key
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name}-${rule.key}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}-edge"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}
