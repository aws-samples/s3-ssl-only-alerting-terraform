variable "custom_tags" {
  type = map(any)
}

variable "account_id" {
  type        = string
  description = "Account ID where the resource will be deployed"
  default     = ""
}

variable "region" {
  type        = string
  description = "AWS Region where the resources will be deployed"
  default     = ""
}

variable "config_rule_name" {
  type        = string
  description = "Config rule name if already existing"
  default     = ""
}

variable "lambda_logs_retention" {
  type        = string
  description = "Remediation and Config Rule Logs Retention in Days"
  default     = "180"
}

variable "alarm_actions" {
  type        = list(string)
  description = "List of resource (ARN) to used as targets for the CW Metric Alarm"
  default     = []
}

variable "buckets_exclusion_list" {
  description = "CSV list of buckets names to be excluded from remediation"
  type        = string
  default     = ""
}
