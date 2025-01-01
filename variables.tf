variable "bucket" {
  type = object({
    name          = string
    create_policy = optional(bool, true)
    force_destroy = optional(bool, true)
  })
  default = null
}

variable "zone_id" {
  default = null
}

variable "cloudfront_enabled" {
  default = true
  nullable = false
}

variable "default_root_object" {
  default = "index.html"
  nullable = false
}

variable "is_ipv6_enabled" {
  default = true
  nullable = false
}

variable "aliases" {
  type = list(string)
}

variable "origins" {
  type = map(object({
    path        = string
    domain_name = optional(string)
    origin_id   = optional(string)
  }))
  default = { 0 = { path = "/www" } }
  nullable = false
}

variable "custom_error_response" {
  type = object({
    error_caching_min_ttl = optional(number, 60)
    error_code            = optional(number, 403)
    response_code         = optional(number, 200)
    response_page_path    = optional(string)
  })
  default = {}
  nullable = false
}

variable "default_cache_behavior" {
  type = object({
    allowed_methods        = optional(set(string), ["GET", "HEAD"])
    cached_methods         = optional(set(string), ["GET", "HEAD"])
    default_ttl            = optional(number, 0)
    max_ttl                = optional(number, 0)
    min_ttl                = optional(number, 0)
    target_origin_id       = optional(string)
    viewer_protocol_policy = optional(string, "redirect-to-https")
    compress               = optional(bool, true)
    forwarded_values = optional(object({
      query_string            = optional(bool, false)
      headers                 = optional(set(string), [])
      query_string_cache_keys = optional(set(string), [])
      cookies = optional(object({
        forward           = optional(string, "none")
        whitelisted_names = optional(set(string), [])
      }), {})
    }), {})
  })
  default = {}
  nullable = false
}

variable "logging_config" {
  type = object({
    include_cookies = optional(bool, false)
    bucket          = optional(string)
    prefix          = optional(string, "access_logs")
  })
  default = {}
  nullable = false
}

variable "geo_restriction" {
  type = object({
    locations = optional(set(string), [])
    type      = optional(string, "none")
  })
  default = {}
  nullable = false
}

variable "viewer_certificate" {
  type = object({
    cloudfront_default_certificate = optional(bool, false)
    acm_certificate_arn            = optional(string)
    minimum_protocol_version       = optional(string, "TLSv1.2_2019")
    ssl_support_method             = optional(string, "sni-only")
  })
  default = {}
  nullable = false
}