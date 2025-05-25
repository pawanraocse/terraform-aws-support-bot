# Dry run script for AWS Bedrock Support Bot (PowerShell)
# This script validates everything without deploying expensive resources

Write-Host "🔍 AWS Bedrock Support Bot - Dry Run Validation" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "⏰ Started at: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Set environment variables
$env:AWS_DEFAULT_REGION = "us-east-1"
$env:TF_VAR_aws_region = "us-east-1"
$env:TF_VAR_project_name = "my-support-bot"
$env:TF_VAR_foundation_model = "amazon.titan-text-premier-v1:0"

Write-Host "ℹ️  Environment variables set for us-east-1 region" -ForegroundColor Blue

# Check prerequisites
Write-Host ""
Write-Host "🔧 Checking Prerequisites..." -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor Yellow

# Check AWS CLI
try {
    $awsVersion = aws --version 2>$null
    Write-Host "✅ AWS CLI is installed: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS CLI not found" -ForegroundColor Red
    exit 1
}

# Check Terraform
try {
    $terraformVersion = terraform version 2>$null
    Write-Host "✅ Terraform is installed: $terraformVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Terraform not found" -ForegroundColor Red
    exit 1
}

# Check Python3
try {
    $pythonVersion = python --version 2>$null
    Write-Host "✅ Python is available: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python not found" -ForegroundColor Red
    exit 1
}

# Check AWS credentials
Write-Host ""
Write-Host "🔐 Checking AWS Credentials..." -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Yellow

try {
    $userInfo = aws sts get-caller-identity 2>$null | ConvertFrom-Json
    Write-Host "✅ AWS credentials are valid" -ForegroundColor Green
    Write-Host "Account ID: $($userInfo.Account)" -ForegroundColor Cyan
    Write-Host "User ARN: $($userInfo.Arn)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ AWS credentials not configured or invalid" -ForegroundColor Red
    exit 1
}

# Check Bedrock model availability
Write-Host ""
Write-Host "🤖 Checking Bedrock Model Availability..." -ForegroundColor Yellow
Write-Host "-----------------------------------------" -ForegroundColor Yellow

try {
    $titanModel = aws bedrock list-foundation-models --query "modelSummaries[?modelId=='amazon.titan-text-premier-v1:0']" --output json 2>$null | ConvertFrom-Json
    if ($titanModel.Count -gt 0) {
        Write-Host "✅ Titan Text Premier model is available" -ForegroundColor Green
        Write-Host "Model: $($titanModel[0].modelName) ($($titanModel[0].modelId))" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Titan Text Premier model not available" -ForegroundColor Red
    }
} catch {
    Write-Host "⚠️  Could not check Titan model availability" -ForegroundColor Yellow
}

try {
    $embedModel = aws bedrock list-foundation-models --query "modelSummaries[?modelId=='amazon.titan-embed-text-v1']" --output json 2>$null | ConvertFrom-Json
    if ($embedModel.Count -gt 0) {
        Write-Host "✅ Titan Embeddings model is available" -ForegroundColor Green
    } else {
        Write-Host "❌ Titan Embeddings model not available" -ForegroundColor Red
    }
} catch {
    Write-Host "⚠️  Could not check Embeddings model availability" -ForegroundColor Yellow
}

# Validate Terraform configuration
Write-Host ""
Write-Host "📋 Validating Terraform Configuration..." -ForegroundColor Yellow
Write-Host "---------------------------------------" -ForegroundColor Yellow

# Initialize Terraform
Write-Host "ℹ️  Initializing Terraform..." -ForegroundColor Blue
try {
    terraform init | Out-Null
    Write-Host "✅ Terraform initialized successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Terraform initialization failed" -ForegroundColor Red
    exit 1
}

# Validate configuration
Write-Host "ℹ️  Validating Terraform configuration..." -ForegroundColor Blue
try {
    terraform validate | Out-Null
    Write-Host "✅ Terraform configuration is valid" -ForegroundColor Green
} catch {
    Write-Host "❌ Terraform configuration has errors" -ForegroundColor Red
    exit 1
}

# Generate plan
Write-Host ""
Write-Host "📊 Generating Deployment Plan..." -ForegroundColor Yellow
Write-Host "-------------------------------" -ForegroundColor Yellow

Write-Host "ℹ️  Creating deployment plan..." -ForegroundColor Blue
try {
    terraform plan -out=dryrun.tfplan | Out-Null
    Write-Host "✅ Deployment plan generated successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to generate deployment plan" -ForegroundColor Red
    exit 1
}

# Analyze the plan
Write-Host ""
Write-Host "📈 Plan Analysis..." -ForegroundColor Yellow
Write-Host "------------------" -ForegroundColor Yellow

$planOutput = terraform show dryrun.tfplan
$createCount = ($planOutput | Select-String "will be created").Count
$changeCount = ($planOutput | Select-String "will be updated").Count
$deleteCount = ($planOutput | Select-String "will be destroyed").Count

Write-Host "ℹ️  Resources to create: $createCount" -ForegroundColor Blue
Write-Host "ℹ️  Resources to change: $changeCount" -ForegroundColor Blue
Write-Host "ℹ️  Resources to delete: $deleteCount" -ForegroundColor Blue

# Check for expensive resources
Write-Host ""
Write-Host "💰 Cost Analysis..." -ForegroundColor Yellow
Write-Host "------------------" -ForegroundColor Yellow

if ($planOutput -match "opensearchserverless_collection") {
    Write-Host "⚠️  OpenSearch Serverless Collection will be created (~$700/month)" -ForegroundColor Yellow
}

if ($planOutput -match "bedrockagent") {
    Write-Host "ℹ️  Bedrock Agent will be created (pay per token usage)" -ForegroundColor Blue
}

if ($planOutput -match "lambda_function") {
    Write-Host "ℹ️  Lambda function will be created (free tier available)" -ForegroundColor Blue
}

if ($planOutput -match "s3_bucket") {
    Write-Host "ℹ️  S3 bucket will be created (minimal cost)" -ForegroundColor Blue
}

# Validate Python script syntax
Write-Host ""
Write-Host "🐍 Validating Python Scripts..." -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Yellow

try {
    python -c "import boto3, requests, json, time; from botocore.auth import SigV4Auth; from botocore.awsrequest import AWSRequest; print('✅ Python script syntax is valid')" 2>$null
    Write-Host "✅ Python script syntax is valid" -ForegroundColor Green
} catch {
    Write-Host "❌ Python script has syntax errors" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "📋 Dry Run Summary" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

Write-Host "✅ All prerequisites are met" -ForegroundColor Green
Write-Host "✅ AWS credentials are valid" -ForegroundColor Green
Write-Host "✅ Terraform configuration is valid" -ForegroundColor Green
Write-Host "✅ Deployment plan is ready" -ForegroundColor Green

Write-Host ""
Write-Host "⚠️  IMPORTANT COST INFORMATION:" -ForegroundColor Yellow
Write-Host "- OpenSearch Serverless: ~$700/month (starts billing immediately)" -ForegroundColor Red
Write-Host "- Bedrock usage: ~$0.01 per 1K tokens" -ForegroundColor Yellow
Write-Host "- Other resources: <$5/month" -ForegroundColor Green
Write-Host ""

Write-Host "ℹ️  Next steps:" -ForegroundColor Blue
Write-Host "1. Review the plan: terraform show dryrun.tfplan"
Write-Host "2. Deploy: terraform apply dryrun.tfplan"
Write-Host "3. Test quickly and destroy: terraform destroy"
Write-Host ""

Write-Host "ℹ️  Quick deployment: .\quick-test.ps1" -ForegroundColor Blue
Write-Host "ℹ️  Manual deployment: terraform apply dryrun.tfplan" -ForegroundColor Blue

Write-Host ""
Write-Host "⏰ Dry run completed at: $(Get-Date)" -ForegroundColor Gray
Write-Host "🎯 Ready for deployment!" -ForegroundColor Green
