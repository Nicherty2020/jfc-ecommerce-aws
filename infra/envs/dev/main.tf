module "edge" {
  source = "../../modules/edge"

  project              = "jfc"
  environment          = "dev"
  api_origin_domain    = var.api_origin_domain
  api_origin_path      = var.api_origin_path
  enable_waf           = var.enable_waf
  waf_rate_limit       = var.waf_rate_limit
  force_destroy_bucket = var.force_destroy_bucket
}

output "cloudfront_domain" {
  value = module.edge.distribution_domain_name
}

output "cloudfront_distribution_id" {
  value = module.edge.distribution_id
}

output "frontend_bucket" {
  value = module.edge.frontend_bucket_name
}
