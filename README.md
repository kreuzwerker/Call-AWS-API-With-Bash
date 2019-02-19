# Motivation
This script is intended to allow generating and signing REST requests to AWS API with [signature version 4](https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html). It is helpful in cases when no SDK/AWS CLI, but bash is available in the environment.
# Requirements
- The script uses AWS EC2 instance profile temporary credentials to sign requests, therefore it can run "as is" only on EC2 instances with a profile associated.
- The IAM role must have necessary permissions.
- OpenSSL and cURL command line tools need to be installed.
- You can use this script with the most AWS APIs, but it was only tested with the [GetParameters](https://docs.aws.amazon.com/systems-manager/latest/APIReference/API_GetParameters.html) API of AWS Systems Manager. You will have to customize it for other use cases and AWS APIs.
- A parameter stored in AWS Systems Manager Parameter Store in the same region, as the AWS EC2 instance the script running on.
# How to run
``` bash -c ". aws-api.sh /example/ssm/parameter" ```