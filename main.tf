module "bucket" {
  source  = "app.terraform.io/ptonini-org/s3-bucket/aws"
  version = "~> 1.0.0"
  count   = var.bucket == null ? 0 : 1
  name    = var.bucket.name
  bucket_policy_statements = [{
    Sid       = "PublicReadGetObject"
    Effect    = "Allow"
    Principal = "*"
    Action    = ["s3:GetObject"],
    Resource  = ["arn:aws:s3:::${var.bucket.name}${var.origins["0"].path}/*"]
  }]
  public_access_block = {
    block_public_acls       = var.bucket.block_public_acls
    restrict_public_buckets = var.bucket.restrict_public_buckets
    ignore_public_acls      = var.bucket.ignore_public_acls
  }
  object_ownership = var.bucket.object_ownership
  create_policy    = var.bucket.create_policy
  force_destroy    = var.bucket.force_destroy
}

module "certificate" {
  source                    = "app.terraform.io/ptonini-org/acm-certificate/aws"
  version                   = "~> 1.0.0"
  count                     = var.zone_id == null ? 0 : 1
  domain_name               = var.aliases[0]
  subject_alternative_names = [for i, a in var.aliases : a if i != 0]
  zone_id                   = var.zone_id
}

resource "aws_cloudfront_distribution" "this" {
  aliases             = var.aliases
  enabled             = var.cloudfront_enabled
  default_root_object = var.default_root_object
  is_ipv6_enabled     = var.is_ipv6_enabled

  dynamic "origin" {
    for_each = var.origins
    content {
      origin_path = origin.value.path
      domain_name = coalesce(origin.value.domain_name, module.bucket[0].this.bucket_domain_name)
      origin_id   = coalesce(origin.value.origin_id, "s3-${module.bucket[0].this.bucket}")
    }
  }

  custom_error_response {
    error_caching_min_ttl = var.custom_error_response.error_caching_min_ttl
    error_code            = var.custom_error_response.error_code
    response_code         = var.custom_error_response.response_code
    response_page_path    = coalesce(var.custom_error_response.response_page_path, "/${var.default_root_object}")
  }

  dynamic "logging_config" {
    for_each = var.logging_config[*]
    content {
      include_cookies = logging_config.value.include_cookies
      bucket          = coalesce(logging_config.value.bucket, module.bucket[0].this.bucket_domain_name)
      prefix          = logging_config.value.prefix
    }
  }

  default_cache_behavior {
    allowed_methods        = var.default_cache_behavior.allowed_methods
    cached_methods         = var.default_cache_behavior.cached_methods
    default_ttl            = var.default_cache_behavior.default_ttl
    max_ttl                = var.default_cache_behavior.max_ttl
    min_ttl                = var.default_cache_behavior.min_ttl
    target_origin_id       = coalesce(var.default_cache_behavior.target_origin_id, "s3-${module.bucket[0].this.bucket}")
    viewer_protocol_policy = var.default_cache_behavior.viewer_protocol_policy
    compress               = var.default_cache_behavior.compress

    forwarded_values {
      headers                 = var.default_cache_behavior.forwarded_values.headers
      query_string            = var.default_cache_behavior.forwarded_values.query_string
      query_string_cache_keys = var.default_cache_behavior.forwarded_values.query_string_cache_keys

      cookies {
        forward           = var.default_cache_behavior.forwarded_values.cookies.forward
        whitelisted_names = var.default_cache_behavior.forwarded_values.cookies.whitelisted_names
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.viewer_certificate.cloudfront_default_certificate
    acm_certificate_arn            = coalesce(var.viewer_certificate.acm_certificate_arn, module.certificate[0].this.arn)
    minimum_protocol_version       = var.viewer_certificate.minimum_protocol_version
    ssl_support_method             = var.viewer_certificate.ssl_support_method
  }

  restrictions {

    geo_restriction {
      locations        = var.geo_restriction.locations
      restriction_type = var.geo_restriction.type
    }
  }
}

module "policy" {
  source  = "app.terraform.io/ptonini-org/iam-policy/aws"
  version = "~> 1.0.0"
  name    = "cloudfront-policy-${aws_cloudfront_distribution.this.id}"
  statement = concat(var.bucket == null ? [] : module.bucket[0].policy_statement, [
    {
      effect   = "Allow"
      actions   = ["cloudfront:ListDistributions"]
      resources = ["*"]
    },
    {
      effect   = "Allow"
      actions   = ["cloudfront:CreateInvalidation"]
      resources = [aws_cloudfront_distribution.this.arn]
    }
  ])
}

module "dns_record" {
  source   = "app.terraform.io/ptonini-org/route53-record/aws"
  version  = "~> 1.0.0"
  for_each = var.cloudfront_enabled && var.zone_id != null ? toset(var.aliases) : []
  name     = each.key
  zone_id  = var.zone_id
  type     = "CNAME"
  records = [
    aws_cloudfront_distribution.this.domain_name
  ]
}




