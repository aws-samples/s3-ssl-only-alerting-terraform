package test

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"

	assert_basic "gotest.tools/assert"

	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/configservice"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestS3SSLOnly(t *testing.T) {

	region := "eu-west-1"
	accountId := aws.GetAccountId(t)
	excluded_bucket := "terratest-excluded-bucket-" + accountId
	bucket_name_no_policy := "terratest-ssl-s3-only-no-policy" + accountId
	bucket_name_with_policy := "terratest-ssl-s3-only-with-policy" + accountId
	tester_buckets := []string{excluded_bucket, bucket_name_no_policy, bucket_name_with_policy}

	terraformOptions := &terraform.Options{
		// Set the path to the Terraform code that will be tested.
		TerraformDir: "../",

		Vars: map[string]interface{}{
			"custom_tags": map[string]string{
				"Environment":    "Test",
				"TargetAccounts": "Tests",
				"DeploymentType": "Terratest",
			},
			"buckets_exclusion_list": excluded_bucket,
			// "config_rule_name":       "s3-bucket-ssl-requests-only-luca-test",
		},
	}

	// Clean up resources with "terraform destroy" at the end of the test.
	defer terraform.Destroy(t, terraformOptions)

	// Run "terraform init" and "terraform apply". Fail the test if there are any errors.
	terraform.InitAndApply(t, terraformOptions)

	outputConfigRuleName := strings.ReplaceAll(terraform.Output(t, terraformOptions, "ConfigRuleName"), "\"", "")

	// Retrieve retention policy
	session := session.Must(session.NewSession())

	// Start config rule eval
	config := configservice.New(session)
	config.DeleteEvaluationResults(&configservice.DeleteEvaluationResultsInput{
		ConfigRuleName: &outputConfigRuleName,
	})

	// Create and configure buckets for tests
	for _, bucket := range tester_buckets {
		aws.CreateS3BucketE(t, region, bucket)
	}
	s3_policy := fmt.Sprintf(`{
		"Id": "Policy1630567609246",
		"Version": "2012-10-17",
		"Statement": [
		  {
			"Sid": "TestPolicy",
			"Action": "s3:*",
			"Effect": "Allow",
			"Resource": "arn:aws:s3:::terratest-ssl-s3-only-with-policy%s",
			"Principal": {"AWS": "arn:aws:iam::%s:root"}
		  }
		]
	  }`, accountId, accountId)
	aws.PutS3BucketPolicy(t, region, bucket_name_with_policy, s3_policy)

	time.Sleep(10 * time.Second)
	ruleArray := []*string{&outputConfigRuleName}
	config.StartConfigRulesEvaluation(&configservice.StartConfigRulesEvaluationInput{
		ConfigRuleNames: ruleArray,
	})
	time.Sleep(1 * time.Minute)

	// Ensure excluded bucket gets no policy
	_, err := aws.GetS3BucketPolicyE(t, region, excluded_bucket)
	assert_basic.ErrorContains(t, err, "NoSuchBucketPolicy")

	// Ensure S3 bucket without policy got a policy
	aws.AssertS3BucketPolicyExists(t, region, bucket_name_no_policy)

	// Ensure S3 buck with already a policy has not been overwritten
	s3_policy_retrieved := aws.GetS3BucketPolicy(t, region, bucket_name_with_policy)
	var s3_policy_json struct{}
	var s3_policy_retrieved_json struct{}
	json.Unmarshal([]byte(s3_policy), &s3_policy_json)
	json.Unmarshal([]byte(s3_policy_retrieved), &s3_policy_retrieved_json)
	assert.Equal(t, s3_policy_json, s3_policy_retrieved_json)
	for _, bucket := range tester_buckets {
		aws.DeleteS3BucketE(t, region, bucket)
	}
}
