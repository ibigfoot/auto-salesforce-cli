#!/bin/bash


export BUILD_DIR=/app/sfdx

export PATH="$BUILD_DIR/vendor/sfdx/cli/bin:$PATH"
export PATH="$BUILD_DIR/vendor/sfdx/jq:$PATH"

sfdx force:doc:commands:list
