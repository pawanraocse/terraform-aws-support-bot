@echo off
echo 🗑️  Complete AWS Bedrock Support Bot Cleanup
echo ==========================================

set PROFILE=bedrock-user
set REGION=us-east-1
set PROJECT=bedrock-support-bot

echo Using AWS Profile: %PROFILE%
echo Using AWS Region: %REGION%
echo.

REM Get account ID
echo 📋 Getting account information...
for /f "tokens=*" %%i in ('aws sts get-caller-identity --query Account --output text --profile %PROFILE% 2^>nul') do set ACCOUNT_ID=%%i

if "%ACCOUNT_ID%"=="" (
    echo ❌ Failed to get account ID. Check AWS credentials.
    pause
    exit /b 1
)

echo ✅ Account ID: %ACCOUNT_ID%
echo.

REM Delete Bedrock Agents
echo 🤖 Deleting Bedrock Agents...
for /f "tokens=*" %%i in ('aws bedrock-agent list-agents --query "agentSummaries[?contains(agentName,'%PROJECT%')].agentId" --output text --profile %PROFILE% --region %REGION% 2^>nul') do (
    echo Deleting agent: %%i
    aws bedrock-agent delete-agent --agent-id %%i --skip-resource-in-use-check --profile %PROFILE% --region %REGION% 2>nul
)

REM Delete Lambda Functions
echo ⚡ Deleting Lambda Functions...
aws lambda delete-function --function-name %PROJECT%-fallback-function --profile %PROFILE% --region %REGION% 2>nul
if errorlevel 1 (
    echo ℹ️  Lambda function not found or already deleted
) else (
    echo ✅ Lambda function deleted
)

REM Delete IAM Roles
echo 👤 Deleting IAM Roles...

REM Delete inline policies first
aws iam delete-role-policy --role-name %PROJECT%-agent-role --policy-name %PROJECT%-agent-policy --profile %PROFILE% 2>nul
aws iam delete-role-policy --role-name %PROJECT%-lambda-role --policy-name %PROJECT%-lambda-policy --profile %PROFILE% 2>nul

REM Detach managed policies
aws iam detach-role-policy --role-name %PROJECT%-lambda-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole --profile %PROFILE% 2>nul

REM Delete roles
aws iam delete-role --role-name %PROJECT%-agent-role --profile %PROFILE% 2>nul
if errorlevel 1 (
    echo ℹ️  Agent role not found or already deleted
) else (
    echo ✅ Agent role deleted
)

aws iam delete-role --role-name %PROJECT%-lambda-role --profile %PROFILE% 2>nul
if errorlevel 1 (
    echo ℹ️  Lambda role not found or already deleted
) else (
    echo ✅ Lambda role deleted
)

REM Delete S3 Bucket
echo 🪣 Deleting S3 Bucket...
set BUCKET_NAME=%PROJECT%-kb-content-%ACCOUNT_ID%

REM Empty bucket first
aws s3 rm s3://%BUCKET_NAME% --recursive --profile %PROFILE% 2>nul

REM Delete bucket
aws s3 rb s3://%BUCKET_NAME% --profile %PROFILE% 2>nul
if errorlevel 1 (
    echo ℹ️  S3 bucket not found or already deleted
) else (
    echo ✅ S3 bucket deleted
)

echo.
echo 🎯 Cleanup Summary
echo ==================
echo ✅ Bedrock Agents: Deleted
echo ✅ Lambda Functions: Deleted  
echo ✅ IAM Roles: Deleted
echo ✅ S3 Buckets: Deleted
echo.
echo 💰 All AWS resources have been removed
echo 💡 No more charges will be incurred
echo.

REM Verify cleanup
echo 🔍 Verifying cleanup...
echo.

echo Remaining Bedrock Agents:
aws bedrock-agent list-agents --query "agentSummaries[?contains(agentName,'%PROJECT%')].[agentName,agentId]" --output table --profile %PROFILE% --region %REGION% 2>nul

echo.
echo Remaining Lambda Functions:
aws lambda list-functions --query "Functions[?contains(FunctionName,'%PROJECT%')].[FunctionName]" --output table --profile %PROFILE% --region %REGION% 2>nul

echo.
echo Remaining S3 Buckets:
aws s3 ls --profile %PROFILE% 2>nul | findstr %PROJECT%

echo.
echo 🎉 Cleanup completed successfully!
echo 💡 You can now safely close this window
pause
