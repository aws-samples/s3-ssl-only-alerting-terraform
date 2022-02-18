from botocore import exceptions
import boto3
import json
import os
import re
from aws_lambda_powertools import Logger


ACTIONABLE_STATUS = 'NON_COMPLIANT'
buckets_excluded_list = os.getenv('BUCKETS_EXCLUSION_LIST', '')
logger = Logger(service="ssl_s3_only_remediation_lambda", level=os.getenv("LOG_LEVEL", "INFO"))
s3 = boto3.client('s3')

def s3_ssl_only_policy(bucket):
    return {
        'Id': 'SSLOnly',
        'Version': '2012-10-17',
        'Statement': [
            {
                'Sid': 'AllowSSLRequestsOnly',
                'Action': 's3:*',
                'Effect': 'Deny',
                'Resource': [f'arn:aws:s3:::{bucket}', f'arn:aws:s3:::{bucket}/*'],
                'Condition': {'Bool': {'aws:SecureTransport': 'false'}},
                'Principal': '*',
            }
        ],
    }


def set_compliant_policy(resources, exclusion_list=[], aws_account_id=None, client=None):
    failures, successes = [], []

    for resource in resources:
        resource_name = resource['complianceResourceId']

        for exclusion_regex in exclusion_list:
            if re.compile(exclusion_regex).match(resource_name):
                logger.debug(
                    f'Bucket {resource_name} in exclusion list {exclusion_list}, skip')
                logger.info(
                    f'Bucket found in exclusion list, skip')
                successes.append(resource_name)

        if resource_name in successes:
            continue

        try:
            logger.info("Setting policy")
            logger.debug(
                f'''Setting policy on bucket {resource_name}''')
            apply_bucket_policy(resource_name, aws_account_id, client)
            logger.debug(f'Apply SSLOnly policy to bucket {resource_name}')
            successes.append(resource_name)
        except Exception:
            logger.exception(
                f'Failed to apply policy {s3_ssl_only_policy(resource_name)}'
            )
            failures.append(resource_name)

    return failures, successes


def apply_bucket_policy(resource_name, aws_account_id=None, client=None):
    try:
        bucket_policy = check_if_policy_exists(
            resource_name, aws_account_id, client)

        if bucket_policy:
            bucket_policy['Statement'].append(
                s3_ssl_only_policy(resource_name)['Statement'][0]
            )
            client.put_bucket_policy(
                Bucket=resource_name,
                Policy=json.dumps(bucket_policy),
                ExpectedBucketOwner=aws_account_id,
            )
            logger.info(
                f'Merging policies.')
            logger.debug(
                f'Bucket {resource_name} with policy {bucket_policy} already present, merge')
        else:
            client.put_bucket_policy(
                Bucket=resource_name,
                Policy=json.dumps(s3_ssl_only_policy(resource_name)),
                ExpectedBucketOwner=aws_account_id,
            )
    except exceptions.ClientError as error:
        raise error


def check_if_policy_exists(resource_name, aws_account_id=None, client=None):
    try:
        bucket_policy = json.loads(client.get_bucket_policy(
            Bucket=resource_name, ExpectedBucketOwner=aws_account_id)['Policy'])

        return bucket_policy
    except exceptions.ClientError as error:
        if error.response['Error']['Code'] == 'NoSuchBucketPolicy':
            logger.info('No previous policy present')

            return None
        else:
            raise error

def get_not_compliant_resources(evaluations):
    return [
        evaluation
        for evaluation in evaluations
        if evaluation['complianceType'] == ACTIONABLE_STATUS
    ]

def lambda_handler(event, context):
    '''Lambda to set the SSLOnly bucket policy

    This lambda works with a event rule trigger coming from AWS Config.

    Raises:
        e: Raises exception in case it cannot set the SSLOnly bucket policy
    '''

    details = event['detail']
    request_parameters = details['requestParameters']
    evaluations = request_parameters['evaluations']
    aws_account_id = context.invoked_function_arn.split(':')[4]
    
    exclusion_list = []
    if buckets_excluded_list != "":
        exclusion_list = [bucket.strip() for bucket in buckets_excluded_list.split(",")]

    not_compliant_resource = get_not_compliant_resources(evaluations)
    logger.debug(f'NOT_COMPLIANT resources {not_compliant_resource}')
    set_compliant_policy(not_compliant_resource,
                         exclusion_list, aws_account_id, s3)
