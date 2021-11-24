module "deploy_s3_ssl_only_remediation" {
  buckets_exclusion_list = "excluded-bucket-a,yet-another-excluded-bucket-*"
  source = "./.."
}
