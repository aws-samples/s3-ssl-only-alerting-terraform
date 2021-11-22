locals {
  config_rule_name = var.config_rule_name == "" ? aws_config_config_rule.s3_ssl_only[0].name : var.config_rule_name
}

resource "aws_cloudwatch_event_rule" "policy_evaluation" {
  name        = "capture-s3-ssl-rules-evaluation"
  description = "Capture AWS Config Evaluation for ${local.config_rule_name}"

  event_pattern = <<EOF
{
  "source": [
    "aws.config"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "config.amazonaws.com"
    ],
    "eventName": [
      "PutEvaluations"
    ],
    "additionalEventData": {
      "configRuleName": [
        "${local.config_rule_name}"
      ]
    }
  }
}
EOF
  tags          = var.custom_tags
}

resource "aws_cloudwatch_event_target" "trigger_lambda_evaluation" {
  rule = aws_cloudwatch_event_rule.policy_evaluation.name
  arn  = aws_lambda_alias.remediation_lambda_live.arn
  depends_on = [
    aws_cloudwatch_event_rule.policy_evaluation
  ]
}
