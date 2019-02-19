#!/bin/bash
function callAwsApi() {
  # Get credentials from instance profile. Should have GetParameter Policy
  IAM_Role="$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/)"
  AccessKeyId="$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/$IAM_Role | grep AccessKeyId | sed -e 's/  "AccessKeyId" : "//' -e 's/",$//')"
  SecretAccessKey="$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/$IAM_Role | grep SecretAccessKey | sed -e 's/  "SecretAccessKey" : "//' -e 's/",$//')"
  Token="$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/$IAM_Role | grep Token | sed -e 's/  "Token" : "//' -e 's/",$//')"

  RequestPostData='{"Names":["'"$1"'"]}'
  HashedPostData=$(echo -n $RequestPostData | openssl dgst -sha256 | awk -F ' ' '{print $2}')
  MyRegion=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone | sed s/.$//)
  AwsService="ssm"
  Target="AmazonSSM.GetParameters"
  HTTPMethod="POST"
  CanonicalURI="/"
  # Set Date and Date+Time
  MyDateAndTime=$(date -u +"%Y%m%dT%H%M%SZ")
  MyDate=$(date -u +"%Y%m%d")

/bin/cat >./get.creq <<EOF
$HTTPMethod
$CanonicalURI

content-type:application/x-amz-json-1.1
host:$AwsService.$MyRegion.amazonaws.com
x-amz-date:$MyDateAndTime
x-amz-security-token:$Token
x-amz-target:$Target

content-type;host;x-amz-date;x-amz-security-token;x-amz-target
$HashedPostData
EOF
  printf %s "$(cat get.creq)" > get.creq # Remove trailing newline, no Perl inside of container

  # Create hashed Canonical request based on the get request
  CanonicalRequestHash=$(openssl dgst -sha256 ./get.creq | awk -F ' ' '{print $2}')

  function hmac_sha256 {
    key="$1"
    data="$2"
    echo -n "$data" | openssl dgst -sha256 -mac HMAC -macopt "$key" | sed 's/^.* //'
  }

  # Four-step signing key calculation
  # This calculates the key for signing with
  dateKey=$(hmac_sha256 key:"AWS4$SecretAccessKey" $MyDate)
  dateRegionKey=$(hmac_sha256 hexkey:$dateKey $MyRegion)
  dateRegionServiceKey=$(hmac_sha256 hexkey:$dateRegionKey $AwsService)
  HexKey=$(hmac_sha256 hexkey:$dateRegionServiceKey "aws4_request")

  # Create String to Sign file
  # This is the string that will be combined with the key to generate the signature
/bin/cat >./get.sts <<EOF
AWS4-HMAC-SHA256
$MyDateAndTime
$MyDate/$MyRegion/$AwsService/aws4_request
$CanonicalRequestHash
EOF
  printf %s "$(cat get.sts)" > get.sts

  # Calculate final signature used in the curl command
  MySignature=$(openssl dgst -sha256 -mac HMAC -macopt hexkey:$HexKey get.sts | awk -F ' ' '{print $2}')

  # Curl AWS Service with signature
  curl -vvv https://$AwsService.$MyRegion.amazonaws.com/ \
    -X $HTTPMethod \
    -H "Authorization: AWS4-HMAC-SHA256 \
        Credential=$AccessKeyId/$MyDate/$MyRegion/$AwsService/aws4_request, \
        SignedHeaders=content-type;host;x-amz-date;x-amz-security-token;x-amz-target, \
        Signature=$MySignature" \
    -H "x-amz-security-token: $Token" \
    -H "x-amz-target: $Target" \
    -H "content-type: application/x-amz-json-1.1" \
    -H "User-Agent: aws-cli/1.11.180 Python/2.7.9 Windows/8 botocore/1.7.38" \
    -d $RequestPostData \
    -H "x-amz-date: $MyDateAndTime"
}

function prepareEnv {
  package=(curl openssl)
  for i in "${package[@]}"
  do
    if [ ! -f "/usr/bin/$i" ]; then
    echo -e "No $i found. Trying to install."
    if [ -d "/etc/apk" ]; then
      apk update
      apk add $i -y
      echo -e "Installation complete."
    elif [ -d "/etc/apt" ]; then
      apt-get update
      apt-get install $i -y
      echo -e "Installation complete."
    elif [ -d "/etc/yum" ]; then
      yum update
      yum install $i -y
      echo -e "Installation complete."
    else
      echo -e "No package manager found. Exiting." | tee >(exec logger)
      exit 1
    fi
  fi
  done
}

prepareEnv
callAwsApi $1