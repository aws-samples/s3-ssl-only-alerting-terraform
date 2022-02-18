resource "aws_serverlessapplicationrepository_cloudformation_stack" "deploy_sar_stack" {
  name = "aws-lambda-powertools-python-layer"

  application_id   = data.aws_serverlessapplicationrepository_application.sar_app.application_id
  semantic_version = data.aws_serverlessapplicationrepository_application.sar_app.semantic_version
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM"
  ]
}

data "aws_serverlessapplicationrepository_application" "sar_app" {
  application_id   = "arn:aws:serverlessrepo:eu-west-1:057560766410:applications/aws-lambda-powertools-python-layer"
  semantic_version = var.aws_powertools_version
}