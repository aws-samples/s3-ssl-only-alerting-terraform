#!/bin/bash

export AWS_SDK_LOAD_CONFIG="true"

if ( [[ -z ${AWS_ACCESS_KEY_ID} ]] || [[ -z ${AWS_SECRET_ACCESS_KEY} ]] ) && [[ -z ${AWS_PROFILE} ]]; then
    echo "[ERROR] Missing AWS credentials variables"
    exit 1
fi

if [[ -z ${AWS_REGION} ]]; then
    echo "[ERROR] Missing AWS_REGION env variable"
    exit 1
fi

# Run security checks and unit tests on python packages
cd ..
# Run pytest
pytest -s
# Run bandit
bandit -r src -c .bandit.yaml -ll --format xml -o test/bandit.xml
# Run Checkov
checkov -d . --quiet --config-file .checkov.yaml -o junitxml > test/checkov_results.xml
# Run terratest
cd -
go test terratest_test.go -timeout 10m -v
