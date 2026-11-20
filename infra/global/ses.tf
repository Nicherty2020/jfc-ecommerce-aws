locals {
  has_domain   = var.domain_name != null
  ses_identity = local.has_domain ? var.domain_name : var.ses_from_email
}

data "aws_route53_zone" "this" {
  count = local.has_domain ? 1 : 0
  name  = var.domain_name
}

resource "aws_sesv2_email_identity" "this" {
  email_identity = local.ses_identity

  dynamic "dkim_signing_attributes" {
    for_each = local.has_domain ? [1] : []
    content {
      next_signing_key_length = "RSA_2048_BIT"
    }
  }

  lifecycle {
    precondition {
      condition     = local.ses_identity != null
      error_message = "Define domain_name o ses_from_email para la identidad de SES."
    }
  }
}

resource "aws_route53_record" "ses_dkim" {
  count = local.has_domain ? 3 : 0

  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = "${aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 1800
  records = ["${aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens[count.index]}.dkim.amazonses.com"]
}
