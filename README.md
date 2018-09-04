# Running Salesforce CLI in Heroku

I was recently asked the question if it would be possible to schedule a download of metadata from a Salesforce instance and store the results into an S3 bucket using Heroku. Now, let me say right up front that just because you can, doesn't mean you should.. but as a thought exercise this is exactly what this little project would help you do. 

At the very least, this is an interesting way to connect and script the Salesforce-CLI in an automated way. 

We are going to use these two commands of the Salesforce CLI, but it should be easy enough to modify if you need to.

```
# use the cli to authenticate to the org
sfdx force:auth:jwt:grant 

# pull metadata that is specified in the package.xml
sfdx force:mdapi:retrieve

```

## 1. Create SSL Certificates
The JWT flow requires some SSL stuff, [CLI documentation](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_auth_jwt_flow.htm#sfdx_dev_auth_jwt_flow) has some excellent details about how to do this. Seriously, go read it. 
TL;DR;? [Create the certificate](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_auth_key_and_cert.htm)

## 2. Create a Connected App
A Connected App is the basis for all types of Identity flows using Salesforce and this one isn't really any different... apart from using the certificate you created in step 1. 
Again, read the documentation linked above :)
TL;DR;? [Create the App](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_auth_connected_app.htm)

## 3. Create the Heroku App
Now here is where you can probably just 

```
git clone https://github.com/ibigfoot/auto-salesforce-cli 
```
to get the code .. but let's pretend you want to do this yourself.. 
Firstly, lets set up all the things you will want to build for this.. 
```
mkdir auto-cli
cd auto-cli
mkdir bin
touch bin/run.sh
touch bin/package.xml
git init .
git add .
git commit -asm "initial commit"
```

Now, create your Heroku application and add the Salesforce-CLI buildpack to it.

```
heroku apps:create 
heroku buildpack:add https://github.com/heroku/salesforce-cli-buildpack.git
```

Once we have this, we want to add a few configuration variables to the application itself. Super handy so you aren't commiting your private key to a source repository or something.
```
heroku config:set SF_USER=<username for you org>
```
We are going to base64 encode the private key to store it in the environment, then when we get to our script we are going to decode it and write it to file. The Salesforce-CLI needs to read this from a file location.

```
heroku config:set SSH_KEY=$(cat server.key | base64)
```

Finally, we want to store things in S3 so lets use our good ole friend the Heroku Addons to make this stupid simple as well.
```
heroku addons:create bucketeer
```

Now, you should be ready to start writing your script!

## 4. Write the Script

The script needs to do a few things.. 
* setup the PATH so that the Salesforce-CLI commands will work.
* write the key env variable to a file
* authenticate to the SF Org
* execute the CLI command to pull MD (or whatever you want it to do)
* write the result to an S3 bucket

```
export BUILD_DIR=/app/sfdx
mkdir $BUILD_DIR

export PATH="$BUILD_DIR/vendor/sfdx/cli/bin:$PATH"
export PATH="$BUILD_DIR/vendor/sfdx/jq:$PATH"

KEYFILE=/app/server.key

# decode the SSH KEY and writes it to the file used by the Salesforce CLI
echo $SSH_KEY | base64 -d >> $KEYFILE

echo 'Authorising with the Salesforce CLI for user '$SF_USER
sfdx force:auth:jwt:grant --clientid $CLIENT_ID --jwtkeyfile $KEYFILE --username $SF_USER --setdefaultdevhubusername --setalias my-hub-org

echo 'Fetching metadata specified in package.xml'
sfdx force:mdapi:retrieve -r /app/backups -u $SF_USER -k /app/bin/package.xml

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

putS3 "/app/backups/" "unpackaged.zip" "/salesforce-cli/backups/$TSTAMP/"

```

## 5. Deploy and Run
Once we are ready to go we can deploy into the Heroku application. Interesting to note, that at the moment we don't have any Procfile at all!

```
git commit -am "making sure I have commited local changes!"
git push heroku master
```

Now that the code has been pushed to Heroku, I can run it using a one-off dyno. 

```
heroku run bin/run.sh
```

Typically, I just run the bash shell however because you might want to poke around and check that everything is being written where is belongs.
You should see something similar if you have your buildpack installed properly.
```
heroku run bash
Running bash on ⬢ afternoon-brushlands-30858... up, run.1698 (Free)
Updating PATH to include Salesforce CLI ...
~ $ 
```
From here, it's simple to run the script to get things kicked off.
```
bin/run.sh
```

## 6. Schedule.
Now for bonus marks, add the Heroku Scheduler and configure a schedule.

## 7. Visualise
For double bonus marks, add some web facing code (I chose Java) to this applicaion so you can read the bucket contents to download contents. 

