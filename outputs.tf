output "ConfigRuleName" {
  value = var.config_rule_name == "" ? aws_config_config_rule.s3_ssl_only[0].name : var.config_rule_name
}

output "RemediationLambdaName" {
  value = aws_lambda_function.remediation_lambda.id
}
