from ..main import get_not_compliant_resources, set_compliant_policy, s3_ssl_only_policy
from boto3 import client
from botocore.stub import Stubber
import json
import logging
import os


class MockContext(object):
    def __init__(self, invoked_function_arn):
        self.invoked_function_arn = invoked_function_arn


CONTEXT = MockContext(
    'arn:aws:lambda:us-east-1:123456789012:function:function')
EVENT = {
    'detail': {
        'requestParameters': {
            'evaluations': [
                {
                    'complianceResourceId': 'bucket-a',
                    'complianceType': 'NON_COMPLIANT'
                },
                {
                    'complianceResourceId': 'bucket-b',
                    'complianceType': 'NON_COMPLIANT'
                },
                {
                    'complianceResourceId': 'bucket-c',
                    'complianceType': 'COMPLIANT'
                },
                {
                    'complianceResourceId': 'excluded-bucket-a',
                    'complianceType': 'NON_COMPLIANT'
                },
                {
                    'complianceResourceId': 'yet-another-excluded-bucket-a',
                    'complianceType': 'NON_COMPLIANT'
                },
            ],
        },
    },
}
buckets_excluded_list = os.getenv(
    'BUCKETS_EXCLUSION_LIST', 'excluded-bucket-a,yet-another-excluded-*')
logger = logging.getLogger()
s3 = client('s3')
stubber = Stubber(s3)

logger.setLevel(logging.INFO)

# Bucket bucket-a: NON_COMPLIANT without policy
stubber.add_client_error(
    'get_bucket_policy',
    expected_params={
        'Bucket': 'bucket-a',
        'ExpectedBucketOwner': '123456789012',
    },
    service_error_code='NoSuchBucketPolicy')
stubber.add_response(
    'put_bucket_policy',
    expected_params={
        'Bucket': 'bucket-a',
        'ExpectedBucketOwner': '123456789012',
        'Policy': json.dumps(s3_ssl_only_policy('bucket-a')),
    },
    service_response={})

# Bucket bucket-b: NON_COMPLIANT with policy
bucket_b_policy = {
    'Id': 'SSLOnly',
    'Statement': [
        {
            'Sid': 'PublicRead',
            'Effect': 'Allow',
            'Principal': '*',
            'Action': [
                's3:GetObject',
                's3:GetObjectVersion'
            ],
            'Resource': [
                'arn:aws:s3:::bucket-b/*',
            ],
        },
    ],
    'Version': '2012-10-17',
}

stubber.add_response(
    'get_bucket_policy',
    expected_params={
        'Bucket': 'bucket-b',
        'ExpectedBucketOwner': '123456789012',
    },
    service_response={
        'Policy': json.dumps(bucket_b_policy)
    })
bucket_b_policy['Statement'].append(
    s3_ssl_only_policy('bucket-b')['Statement'][0]
)
stubber.add_response(
    'put_bucket_policy',
    expected_params={
        'Bucket': 'bucket-b',
        'ExpectedBucketOwner': '123456789012',
        'Policy': json.dumps(bucket_b_policy),
    },
    service_response={})

with stubber:
    details = EVENT['detail']
    request_parameters = details['requestParameters']
    evaluations = request_parameters['evaluations']
    aws_account_id = CONTEXT.invoked_function_arn.split(':')[4]
    exclusion_list = [bucket.strip()
                      for bucket in buckets_excluded_list.split(',')]

    not_compliant_resource = get_not_compliant_resources(evaluations)
    logger.info(f'NOT_COMPLIANT resources {not_compliant_resource}')
    failures, successes = set_compliant_policy(not_compliant_resource,
                                               exclusion_list, aws_account_id, s3)

    assert failures == []
    assert successes == [
        'bucket-a',
        'bucket-b',
        'excluded-bucket-a',
        'yet-another-excluded-bucket-a']
