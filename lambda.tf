locals {
  lambda_zip_path   = "${path.module}/src/remediation-lambda.zip"
  lambda_name       = "ssl_s3_only_remediation_lambda"
  lambda_alias_name = "live"
}

data "archive_file" "remediation_lambda_zip" {
  type        = "zip"
  output_path = local.lambda_zip_path
  source_dir  = "${path.module}/src/remediation"
}

resource "aws_lambda_function" "remediation_lambda" {
  #checkov:skip=CKV_AWS_117/Lambda in VPC
  #checkov:skip=CKV_AWS_116/Ensure that AWS Lambda function is configured for a Dead Letter Queue(DLQ)

  depends_on                     = [data.archive_file.remediation_lambda_zip]
  function_name                  = local.lambda_name
  filename                       = local.lambda_zip_path
  role                           = aws_iam_role.lambda.arn
  handler                        = "main.lambda_handler"
  source_code_hash               = data.archive_file.remediation_lambda_zip.output_base64sha256
  publish                        = true
  runtime                        = "python3.8"
  timeout                        = 30
  layers = [ aws_serverlessapplicationrepository_cloudformation_stack.deploy_sar_stack.outputs.LayerVersionArn ]
  reserved_concurrent_executions = -1
  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
    "BUCKETS_EXCLUSION_LIST" = var.buckets_exclusion_list }
  }

  tags = var.custom_tags
}

resource "aws_lambda_alias" "remediation_lambda_live" {
  depends_on       = [aws_lambda_function.remediation_lambda]
  name             = local.lambda_alias_name
  description      = "Live Alias for Lambda function with hash"
  function_name    = aws_lambda_function.remediation_lambda.arn
  function_version = aws_lambda_function.remediation_lambda.version
}

resource "aws_cloudwatch_log_group" "lambda-logs" {
  #checkov:skip=CKV_AWS_158:it has been decided not to use a custom KMS due to pricing reasons. Standard KMS is applied by default in this case.
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = var.lambda_logs_retention

}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "[${local.lambda_name}] Lambda Error Count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Monitor Errors on Lambda"
  dimensions = {
    Resource     = "${local.lambda_name}:${local.lambda_alias_name}"
    FunctionName = local.lambda_name
  }
  insufficient_data_actions = []
  unit                      = "Count"
  alarm_actions             = var.alarm_actions
  tags                      = var.custom_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttling" {
  alarm_name          = "[${local.lambda_name}] Lambda Throttling"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Monitor Lambda Throttling"
  dimensions = {
    Resource     = "${local.lambda_name}:${local.lambda_alias_name}"
    FunctionName = local.lambda_name
  }
  insufficient_data_actions = []
  unit                      = "Count"
  alarm_actions             = var.alarm_actions
  tags                      = var.custom_tags
}
