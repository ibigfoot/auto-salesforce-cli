#!/bin/bash


export BUILD_DIR=/app/sfdx

export PATH="$BUILD_DIR/vendor/sfdx/cli/bin:$PATH"
export PATH="$BUILD_DIR/vendor/sfdx/jq:$PATH"

echo 'Authorising with the Salesforce CLI for user '$SF_USER
sfdx force:auth:jwt:grant --clientid $CLIENT_ID --jwtkeyfile /app/server.key --username $SF_USER --setdefaultdevhubusername --setalias my-hub-org

echo 'Fetching metadata specified in package.xml'
sfdx force:mdapi:retrieve -r /app/backups -u $SF_USER -k /app/bin/package.xml


echo 'writing results to S3 bucket'
S3KEY=$BUCKETEER_AWS_ACCESS_KEY_ID
S3SECRET=$BUCKETEER_AWS_SECRET_ACCESS_KEY

function putS3
{
  path=$1
  file=$2
  aws_path=$3
  bucket=$BUCKETEER_BUCKET_NAME
  date=$(date +"%a, %d %b %Y %T %z")
  acl="x-amz-acl:public-read"
  content_type='application/x-compressed-tar'
  string="PUT\n\n$content_type\n$date\n$acl\n/$bucket$aws_path$file"
  signature=$(echo -en "${string}" | openssl sha1 -hmac "${S3SECRET}" -binary | base64)
  curl -X PUT -T "$path/$file" \
    -H "Host: $bucket.s3.amazonaws.com" \
    -H "Date: $date" \
    -H "Content-Type: $content_type" \
    -H "$acl" \
    -H "Authorization: AWS ${S3KEY}:$signature" \
    "https://$bucket.s3.amazonaws.com$aws_path$file"
}

TSTAMP=$(date +%s)

for file in "/backups"/*; do
  putS3 "/app/backups" "${file##*/}" "/salesforce-cli/backups/$TSTAMP/"
