#!/bin/bash

export BUILD_DIR=/app/sfdx
export BACKUP_DIR=/app/backups

mkdir $BUILD_DIR
mkdir $BACKUP_DIR

export PATH="$BUILD_DIR/vendor/sfdx/cli/bin:$PATH"
export PATH="$BUILD_DIR/vendor/sfdx/jq:$PATH"

KEYFILE=/app/server.key

echo $SSH_KEY | base64 -d >> $KEYFILE

echo 'Authorising with the Salesforce CLI for user '$SF_USER
sfdx force:auth:jwt:grant --clientid $CLIENT_ID --jwtkeyfile $KEYFILE --username $SF_USER --setdefaultdevhubusername --setalias my-hub-org

echo 'Fetching metadata specified in package.xml'
sfdx force:mdapi:retrieve -r $BACKUP_DIR -u $SF_USER -k /app/bin/package.xml


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

    echo "wrote $file to https://$bucket.s3.amazonaws.com$aws_path$file"
}

TSTAMP=$(date +%s)

putS3 $BACKUP_DIR "unpackaged.zip" "/salesforce-cli/backups/$TSTAMP/"

echo 'completed writing - exiting'
