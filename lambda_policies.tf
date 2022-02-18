resource "aws_iam_role" "lambda" {
  name               = "${local.lambda_name}-management-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "aws_xray_write_only_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "lambdas_permissions" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_remediation_lambda_evaluation" {
  statement_id  = "AllowExecutionFromCloudWatchEvaluation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_alias.remediation_lambda_live.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.policy_evaluation.arn
}

data "aws_iam_policy_document" "allow_put_policy_on_lambda" {
  statement {
    sid       = "AllowPutPolicyOnS3"
    resources = ["arn:aws:s3:::*", "arn:aws:s3:::*/*"]
    actions = ["s3:PutBucketPolicy",
    "s3:GetBucketPolicy"]
  }
  statement {
    sid = "AllowEncryptionDecryption"
    resources = [ aws_kms_alias.lambda_encryption.target_key_arn ]
    actions = [ "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey" 
    ]
  }
}

resource "aws_iam_role_policy" "allow_put_policy_on_lambda" {
  name   = "allow_put_policy_on_s3"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.allow_put_policy_on_lambda.json
}
