resource "aws_config_config_rule" "s3_ssl_only" {
  count = var.config_rule_name == "" ? 1 : 0
  name  = "s3-bucket-ssl-requests-only"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SSL_REQUESTS_ONLY"
  }

  tags = var.custom_tags
}
