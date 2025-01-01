output "this" {
  value = aws_cloudfront_distribution.this
}


output "policy_arn" {
  value = module.policy.this.arn
}

output "certificate_domain_validation_options" {
  value = one(module.certificate[*].domain_validation_options)
}