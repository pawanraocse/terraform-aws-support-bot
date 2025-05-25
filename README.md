# AWS Bedrock Support Bot

A simple AWS Bedrock-powered support bot using Python SDK deployment.

## Features

- **AWS Bedrock Agent** with Amazon Titan foundation model
- **Lambda Function** for fallback responses  
- **S3 Integration** for content storage
- **Python SDK Deployment** - reliable and cost-effective

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   User Query    │───▶│  Bedrock Agent   │───▶│ Lambda Function │
└─────────────────┘    └──────────────────┘    │   (Fallback)    │
                                │               └─────────────────┘
                                │               
                                ▼               
                       ┌─────────────────┐    
                       │   S3 Bucket     │    
                       │ (Content Store) │    
                       └─────────────────┘    
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Python 3.9+
- Access to AWS Bedrock foundation models (Titan Text Premier)

## Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd aws-bedrock-support-bot
```

### 2. Deploy Infrastructure

```bash
# Deploy using Python SDK
python3 deploy-bedrock-bot.py
```

### 3. Test the Agent

```bash
# Test your Bedrock agent (use the agent ID from deployment output)
aws bedrock-agent-runtime invoke-agent \
  --agent-id <your-agent-id> \
  --agent-alias-id TSTALIASID \
  --session-id test-session \
  --input-text "Hello, can you help me?"
```

### 4. Cleanup

```bash
# Remove all resources when done
python3 cleanup-bedrock-bot.py
```

## Configuration

The deployment script uses these defaults:
- **Region**: us-east-1
- **Foundation Model**: amazon.titan-text-premier-v1:0
- **Project Name**: bedrock-support-bot

## Cost Considerations

### Monthly Costs (Estimated)

- **Bedrock Model Usage**: ~$0.01 per 1K tokens
- **Lambda Function**: Free tier (1M requests/month)
- **S3 Storage**: ~$0.023 per GB/month

**Total**: Very low cost - only pay for actual usage!

## Files

- `deploy-bedrock-bot.py` - Main deployment script
- `cleanup-bedrock-bot.py` - Cleanup script
- `README.md` - This documentation
- `.gitignore` - Git ignore rules

## Troubleshooting

### Common Issues

1. **Bedrock Model Access**: Ensure you have access to Titan Text Premier model in AWS Bedrock console.

2. **IAM Permissions**: Verify your AWS user has permissions for Bedrock, Lambda, S3, and IAM operations.

3. **Agent Status**: The script waits for agent creation - this can take 1-2 minutes.

### Debug Commands

```bash
# Check Bedrock model availability
aws bedrock list-foundation-models --query "modelSummaries[?contains(modelId,'titan-text')]"

# Check deployed resources
aws bedrock-agent list-agents
aws lambda list-functions --query "Functions[?contains(FunctionName,'bedrock')]"
aws s3 ls | grep bedrock
```

## Why Python SDK Instead of Terraform?

- ✅ **Better error handling** for AWS Bedrock services
- ✅ **No OpenSearch Serverless** complexity (saves $700/month)
- ✅ **Faster deployment** and debugging
- ✅ **More reliable** for newer AWS services
- ✅ **Cost-effective** for testing and development

## Security

- All resources use AWS-managed encryption
- S3 buckets have public access blocked
- IAM roles follow least privilege principle
- Lambda functions have minimal required permissions

## License

MIT License - see LICENSE file for details.
