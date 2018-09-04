#!/bin/bash


export BUILD_DIR=/app/sfdx

export PATH="$BUILD_DIR/vendor/sfdx/cli/bin:$PATH"
export PATH="$BUILD_DIR/vendor/sfdx/jq:$PATH"


sfdx force:auth:jwt:grant --clientid $CLIENT_ID --jwtkeyfile /app/server.key --username $SF_USER --setdefaultdevhubusername --setalias my-hub-org

## sfdx force:mdapi:retrieve -r ../backups -u <username> -k ./package.xml

