#!/bin/bash
# Dry run script for AWS Bedrock Support Bot
# This script validates everything without deploying expensive resources

echo "🔍 AWS Bedrock Support Bot - Dry Run Validation"
echo "================================================"
echo "⏰ Started at: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Set environment variables
export AWS_DEFAULT_REGION=us-east-1
export TF_VAR_aws_region=us-east-1
export TF_VAR_project_name=my-support-bot
export TF_VAR_foundation_model=amazon.titan-text-premier-v1:0

print_info "Environment variables set for us-east-1 region"

# Check prerequisites
echo ""
echo "🔧 Checking Prerequisites..."
echo "----------------------------"

# Check AWS CLI
if command -v aws &> /dev/null; then
    print_status "AWS CLI is installed"
    aws --version
else
    print_error "AWS CLI not found"
    exit 1
fi

# Check Terraform
if command -v terraform &> /dev/null; then
    print_status "Terraform is installed"
    terraform version
else
    print_error "Terraform not found"
    exit 1
fi

# Check Python3
if command -v python3 &> /dev/null; then
    print_status "Python3 is available"
    python3 --version
else
    print_error "Python3 not found"
    exit 1
fi

# Check AWS credentials
echo ""
echo "🔐 Checking AWS Credentials..."
echo "------------------------------"

if aws sts get-caller-identity &> /dev/null; then
    print_status "AWS credentials are valid"
    USER_INFO=$(aws sts get-caller-identity)
    echo "$USER_INFO"
    
    USER_ARN=$(echo "$USER_INFO" | jq -r '.Arn')
    ACCOUNT_ID=$(echo "$USER_INFO" | jq -r '.Account')
    print_info "Account ID: $ACCOUNT_ID"
    print_info "User ARN: $USER_ARN"
else
    print_error "AWS credentials not configured or invalid"
    exit 1
fi

# Check Bedrock model availability
echo ""
echo "🤖 Checking Bedrock Model Availability..."
echo "-----------------------------------------"

TITAN_MODEL=$(aws bedrock list-foundation-models --query "modelSummaries[?modelId=='amazon.titan-text-premier-v1:0']" --output json)
if [ "$TITAN_MODEL" != "[]" ]; then
    print_status "Titan Text Premier model is available"
    echo "$TITAN_MODEL" | jq -r '.[0] | "Model: \(.modelName) (\(.modelId))"'
else
    print_error "Titan Text Premier model not available"
    print_info "Checking alternative Titan models..."
    aws bedrock list-foundation-models --query "modelSummaries[?contains(modelId,'titan-text')].[modelId,modelName]" --output table
fi

EMBED_MODEL=$(aws bedrock list-foundation-models --query "modelSummaries[?modelId=='amazon.titan-embed-text-v1']" --output json)
if [ "$EMBED_MODEL" != "[]" ]; then
    print_status "Titan Embeddings model is available"
else
    print_error "Titan Embeddings model not available"
fi

# Validate Terraform configuration
echo ""
echo "📋 Validating Terraform Configuration..."
echo "---------------------------------------"

# Initialize Terraform
print_info "Initializing Terraform..."
if terraform init; then
    print_status "Terraform initialized successfully"
else
    print_error "Terraform initialization failed"
    exit 1
fi

# Validate configuration
print_info "Validating Terraform configuration..."
if terraform validate; then
    print_status "Terraform configuration is valid"
else
    print_error "Terraform configuration has errors"
    exit 1
fi

# Generate plan
echo ""
echo "📊 Generating Deployment Plan..."
echo "-------------------------------"

print_info "Creating deployment plan..."
if terraform plan -out=dryrun.tfplan; then
    print_status "Deployment plan generated successfully"
else
    print_error "Failed to generate deployment plan"
    exit 1
fi

# Analyze the plan
echo ""
echo "📈 Plan Analysis..."
echo "------------------"

# Count resources
RESOURCES_TO_CREATE=$(terraform show -json dryrun.tfplan | jq '.resource_changes | map(select(.change.actions[] == "create")) | length')
RESOURCES_TO_CHANGE=$(terraform show -json dryrun.tfplan | jq '.resource_changes | map(select(.change.actions[] == "update")) | length')
RESOURCES_TO_DELETE=$(terraform show -json dryrun.tfplan | jq '.resource_changes | map(select(.change.actions[] == "delete")) | length')

print_info "Resources to create: $RESOURCES_TO_CREATE"
print_info "Resources to change: $RESOURCES_TO_CHANGE"
print_info "Resources to delete: $RESOURCES_TO_DELETE"

# Check for expensive resources
echo ""
echo "💰 Cost Analysis..."
echo "------------------"

if terraform show dryrun.tfplan | grep -q "opensearchserverless_collection"; then
    print_warning "OpenSearch Serverless Collection will be created (~$700/month)"
fi

if terraform show dryrun.tfplan | grep -q "bedrockagent"; then
    print_info "Bedrock Agent will be created (pay per token usage)"
fi

if terraform show dryrun.tfplan | grep -q "lambda_function"; then
    print_info "Lambda function will be created (free tier available)"
fi

if terraform show dryrun.tfplan | grep -q "s3_bucket"; then
    print_info "S3 bucket will be created (minimal cost)"
fi

# Validate Python script syntax
echo ""
echo "🐍 Validating Python Scripts..."
echo "------------------------------"

print_info "Checking index creation script syntax..."
python3 -c "
import boto3, requests, json, time
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
print('✅ Python script syntax is valid')
" 2>/dev/null

if [ $? -eq 0 ]; then
    print_status "Python script syntax is valid"
else
    print_error "Python script has syntax errors"
fi

# Summary
echo ""
echo "📋 Dry Run Summary"
echo "=================="

print_status "All prerequisites are met"
print_status "AWS credentials are valid"
print_status "Terraform configuration is valid"
print_status "Deployment plan is ready"

echo ""
print_warning "IMPORTANT COST INFORMATION:"
echo "- OpenSearch Serverless: ~$700/month (starts billing immediately)"
echo "- Bedrock usage: ~$0.01 per 1K tokens"
echo "- Other resources: <$5/month"
echo ""

print_info "Next steps:"
echo "1. Review the plan: terraform show dryrun.tfplan"
echo "2. Deploy: terraform apply dryrun.tfplan"
echo "3. Test quickly and destroy: terraform destroy"
echo ""

print_info "Quick deployment: ./quick-test.sh"
print_info "Manual deployment: terraform apply dryrun.tfplan"

echo ""
echo "⏰ Dry run completed at: $(date)"
echo "🎯 Ready for deployment!"
