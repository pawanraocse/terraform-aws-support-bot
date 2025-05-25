@echo off
echo Testing AWS Bedrock Support Bot
echo ================================

REM Set your agent ID here (replace with actual ID from deployment)
set AGENT_ID=YOUR_AGENT_ID_HERE

REM Check if agent ID is set
if "%AGENT_ID%"=="YOUR_AGENT_ID_HERE" (
    echo ERROR: Please set your actual agent ID in this script
    echo Run: aws bedrock-agent list-agents --profile bedrock-user --region us-east-1
    pause
    exit /b 1
)

echo Using Agent ID: %AGENT_ID%
echo.

echo Test 1: Basic Greeting
echo -----------------------
aws bedrock-agent-runtime invoke-agent ^
  --agent-id %AGENT_ID% ^
  --agent-alias-id TSTALIASID ^
  --session-id test-1 ^
  --input-text "Hello, can you help me?" ^
  --profile bedrock-user ^
  --region us-east-1 ^
  --query "completion" ^
  --output text

echo.
echo Test 2: Support Question
echo ------------------------
aws bedrock-agent-runtime invoke-agent ^
  --agent-id %AGENT_ID% ^
  --agent-alias-id TSTALIASID ^
  --session-id test-2 ^
  --input-text "I need help with my account" ^
  --profile bedrock-user ^
  --region us-east-1 ^
  --query "completion" ^
  --output text

echo.
echo Test 3: Technical Question
echo --------------------------
aws bedrock-agent-runtime invoke-agent ^
  --agent-id %AGENT_ID% ^
  --agent-alias-id TSTALIASID ^
  --session-id test-3 ^
  --input-text "How do I reset my password?" ^
  --profile bedrock-user ^
  --region us-east-1 ^
  --query "completion" ^
  --output text

echo.
echo Testing completed!
pause
