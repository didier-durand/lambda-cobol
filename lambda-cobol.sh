#!/bin/bash

REPORT='report.md'
touch "$REPORT"
echo '```' >> "$REPORT"

echo ' ' >> "$REPORT"
echo "### execution date: $(date -u)" | tee -a "$REPORT"

LAMBDA_NAME='lambda-cobol-hello-world'
SAM_TEMPLATE='lambda-cobol-sam.yaml'
STACK_NAME='lambda-cobol-stack'
BUILD_DIR='build'
BUCKET_NAME='net.didier-durand.lambda-code'

set -e
trap 'catch $? $LINENO' EXIT
catch() {
  if [ "$1" != "0" ]; then
    echo "Error $1 occurred on line $2"
  fi
}

# cleanup
rm -rf lib
rm -rf hello-world

# Build the Cobol binary in the container
echo "### Compiling Cobol in Docker container..."
docker build -t cobol-builder .
docker create --name cobol cobol-builder:latest

# Copy the built binary and library
docker cp cobol:/app/hello-world .
docker cp cobol:/app/lib .

# Remove the builder
docker rm cobol

# Check Docker results
echo ' '
echo "current dir is: $(pwd)"
ls -lh .
echo ' '
echo "current dir is: $(pwd)/lib"
ls -lh ./lib
echo ' '

echo "### Creating lambda package..."
mkdir lambda-cobol.code
cp -R hello-world lib bootstrap Makefile lambda-cobol.code
#lambda bootstap must have execute permission set
chmod ugo+x lambda-cobol.code/bootstrap
echo "dir: $(pwd)/lambda-cobol.code"
ls -lh "$(pwd)/lambda-cobol.code"
echo "dir: $(pwd)/lambda-cobol.code/lib"
ls -lh "$(pwd)/lambda-cobol.code/lib"

echo "### Cleaning up existing CF stack..."
aws cloudformation describe-stacks --region "$AWS_REGION"
(aws cloudformation delete-stack --region "$AWS_REGION" --stack-name "$STACK_NAME" && sleep 30s) || true

# Check other existing lambdas
echo ' ' | tee -a "$REPORT"
echo "### Check existing Lambdas functions..." | tee -a "$REPORT"
aws lambda list-functions --region "$AWS_REGION" | tee -a "$REPORT"

# Build Lambda
echo ' ' | tee -a "$REPORT"
echo "### Starting SAM build..." | tee -a "$REPORT"
mkdir "$BUILD_DIR"
sam  build --build-dir "$BUILD_DIR" --template "$SAM_TEMPLATE" | tee -a "$REPORT"
echo "dir: $(pwd)/$BUILD_DIR"
ls -lh "$(pwd)/$BUILD_DIR"
echo "dir: $(pwd)/$BUILD_DIR/HelloWorldCobol"
ls -lh "$(pwd)/$BUILD_DIR/HelloWorldCobol"


echo ' ' | tee -a "$REPORT"
echo "### Starting SAM deployment..." | tee -a "$REPORT"
sam  deploy --template "$SAM_TEMPLATE"  --stack-name "$STACK_NAME" --s3-bucket "$BUCKET_NAME" --capabilities CAPABILITY_IAM | tee -a "$REPORT"

echo ' ' | tee -a "$REPORT"
echo "### Listing active Lambdas..."
aws lambda list-functions --region "$AWS_REGION"

echo ' ' | tee -a "$REPORT"
echo "### Inkoking deployed Lambda synchronously from CLI..." | tee -a "$REPORT"
aws lambda invoke --function "$LAMBDA_NAME" --region="$AWS_REGION" outfile.txt | tee -a "$REPORT"
echo 'invocation result:' | tee -a "$REPORT"
cat outfile.txt | tee -a "$REPORT"
#check if ok
cat outfile.txt | grep 'Hello World from COBOL'

echo ' ' | tee -a "$REPORT" && echo ' ' | tee -a "$REPORT"
echo "### Obtaining API gateway config..." | tee -a "$REPORT"
aws apigateway get-rest-apis --region "$AWS_REGION" | tee -a "$REPORT"
API_ID=$(aws apigateway get-rest-apis --region "$AWS_REGION" --output text --query "items[?name == \`$STACK_NAME\`].id | [0]")
echo "api id: $API_ID" | tee -a "$REPORT"

LAMBDA_URL="https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/Prod/$LAMBDA_NAME"
echo ' ' | tee -a "$REPORT"
echo "### Running curl https request to $LAMBDA_URL ..." | tee -a "$REPORT"
curl "$LAMBDA_URL" | tee -a "$REPORT"

sleep 3s

echo ' ' >> "$REPORT"
echo '```' >> "$REPORT"

rm -f README.md
cat README.template.md "$REPORT" > README.md

echo ' '
echo "README.md:"
cat README.md

#aws apigateway get-resources --region "$AWS_REGION" --rest-api-id "$API_ID"  
#aws apigateway get-resources --region us-east1 --rest-api-id 5puota8276 --query "items[?pathPart == \`lambda-cobol-hello-world\`].id | [0]"



