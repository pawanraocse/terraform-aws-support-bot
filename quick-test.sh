#!/bin/bash
# Quick test script for AWS Bedrock Support Bot

echo "🚀 Starting quick test of AWS Bedrock Support Bot"
echo "⏰ Test started at: $(date)"

# Set environment variables
export AWS_DEFAULT_REGION=us-east-1
export TF_VAR_aws_region=us-east-1
export TF_VAR_project_name=my-support-bot
export TF_VAR_foundation_model=amazon.titan-text-premier-v1:0

echo "📦 Deploying infrastructure..."
terraform init
terraform apply -auto-approve

if [ $? -eq 0 ]; then
    echo "✅ Deployment successful!"
    
    # Get outputs
    S3_BUCKET=$(terraform output -raw s3_bucket_name)
    KB_ID=$(terraform output -raw knowledge_base_id)
    AGENT_ID=$(terraform output -raw agent_id)
    
    echo "📊 Infrastructure Details:"
    echo "S3 Bucket: $S3_BUCKET"
    echo "Knowledge Base ID: $KB_ID"
    echo "Agent ID: $AGENT_ID"
    
    # Upload sample content
    echo "📄 Uploading sample content..."
    aws s3 cp sample-kb-content.md s3://$S3_BUCKET/
    
    # Start ingestion job
    echo "🔄 Starting knowledge base ingestion..."
    DATA_SOURCE_ID=$(aws bedrock-agent list-data-sources --knowledge-base-id $KB_ID --query "dataSourceSummaries[0].dataSourceId" --output text)
    aws bedrock-agent start-ingestion-job --knowledge-base-id $KB_ID --data-source-id $DATA_SOURCE_ID
    
    echo "⏳ Waiting for ingestion to complete (30 seconds)..."
    sleep 30
    
    # Prepare agent
    echo "🤖 Preparing agent..."
    aws bedrock-agent prepare-agent --agent-id $AGENT_ID
    
    echo "⏳ Waiting for agent preparation (30 seconds)..."
    sleep 30
    
    # Test the agent
    echo "🧪 Testing agent..."
    aws bedrock-agent-runtime invoke-agent \
        --agent-id $AGENT_ID \
        --agent-alias-id TSTALIASID \
        --session-id test-session-$(date +%s) \
        --input-text "How do I reset my password?" \
        --output text
    
    echo "✅ Test completed!"
    echo "💰 IMPORTANT: Resources are still running and incurring costs!"
    echo "🗑️  Run 'terraform destroy -auto-approve' to clean up"
    
else
    echo "❌ Deployment failed!"
fi

echo "⏰ Test completed at: $(date)"
