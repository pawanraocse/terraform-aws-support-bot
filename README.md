# AWS Bedrock Support Bot

This Terraform project creates a complete AWS Bedrock-based support bot with the following components:

## Architecture

1. **S3 Bucket**: Stores knowledge base content (documents, FAQs, etc.)
2. **OpenSearch Serverless Collection**: Vector database for knowledge base
3. **Bedrock Knowledge Base**: Processes and indexes content from S3
4. **Lambda Function**: Fallback function for custom responses when KB can't answer
5. **Bedrock Agent**: Main agent that uses the knowledge base and action groups
6. **IAM Roles & Policies**: Proper permissions for all components

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0 installed
- Access to AWS Bedrock service in your region
- Bedrock foundation models enabled (Claude 3 Sonnet and Titan Embeddings)

## Setup Instructions

### 1. Enable Bedrock Models

Before deploying, ensure you have access to the required foundation models in AWS Bedrock:

1. Go to AWS Bedrock console
2. Navigate to "Model access" in the left sidebar
3. Request access to:
   - nthropic.claude-3-sonnet-20240229-v1:0 (for the agent)
   - mazon.titan-embed-text-v1 (for embeddings)

### 2. Configure Variables

1. Copy the example variables file:
   `ash
   cp terraform.tfvars.example terraform.tfvars
   `

2. Edit 	erraform.tfvars with your desired values:
   `hcl
   aws_region = "us-east-1"
   project_name = "my-support-bot"
   foundation_model = "anthropic.claude-3-sonnet-20240229-v1:0"
   lambda_fallback_message = "Custom fallback message here"
   `

### 3. Deploy Infrastructure

1. Initialize Terraform:
   `ash
   terraform init
   `

2. Plan the deployment:
   `ash
   terraform plan
   `

3. Apply the configuration:
   `ash
   terraform apply
   `

### 4. Upload Knowledge Base Content

After deployment, upload your support documents to the S3 bucket:

1. Get the bucket name from Terraform output:
   `ash
   terraform output s3_bucket_name
   `

2. Upload your documents:
   `ash
   aws s3 cp your-documents/ s3://BUCKET_NAME/ --recursive
   `

3. Sync the knowledge base data source:
   `ash
   aws bedrock-agent start-ingestion-job \
     --knowledge-base-id  \
     --data-source-id DATA_SOURCE_ID
   `

### 5. Prepare and Test the Agent

1. Prepare the agent (this creates an alias):
   `ash
   aws bedrock-agent prepare-agent \
     --agent-id 
   `

2. Test the agent:
   `ash
   aws bedrock-agent-runtime invoke-agent \
     --agent-id  \
     --agent-alias-id TSTALIASID \
     --session-id test-session-1 \
     --input-text "Hello, I need help with my account"
   `

## File Structure

`
aws-bedrock-support-bot/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── terraform.tfvars.example   # Example variables file
├── README.md                  # This file
└── fallback_function.zip      # Generated Lambda deployment package
`

## Components Details

### S3 Bucket
- Stores knowledge base documents
- Versioning enabled
- Server-side encryption
- Public access blocked

### Knowledge Base
- Uses Amazon Titan embeddings
- OpenSearch Serverless for vector storage
- Automatic document processing and indexing

### Lambda Function
- Python 3.9 runtime
- Provides fallback responses
- Customizable response logic
- Integrated with Bedrock agent as action group

### Bedrock Agent
- Uses Claude 3 Sonnet model
- Associated with knowledge base
- Fallback action group for unhandled queries
- Configurable instructions

## Customization

### Lambda Function
The fallback Lambda function can be customized to:
- Integrate with external APIs
- Implement custom business logic
- Route to human agents
- Log interactions

### Knowledge Base Content
Supported file formats:
- PDF documents
- Text files
- Word documents
- HTML files

### Agent Instructions
Modify the agent instructions in main.tf to customize behavior:
`hcl
instruction = "Your custom agent instructions here..."
`

## Monitoring and Logging

- CloudWatch logs for Lambda function
- Bedrock agent invocation logs
- S3 access logs (optional)

## Cost Considerations

- OpenSearch Serverless: Pay per OCU (OpenSearch Compute Units)
- Bedrock model invocations: Pay per token
- Lambda: Pay per invocation and duration
- S3: Pay for storage and requests

## Cleanup

To destroy all resources:
`ash
terraform destroy
`

## Troubleshooting

### Common Issues

1. **Model Access Denied**: Ensure Bedrock models are enabled in your region
2. **Permission Errors**: Check IAM roles and policies
3. **Knowledge Base Empty**: Ensure documents are uploaded and ingestion job completed
4. **Agent Not Responding**: Verify agent is prepared and has valid alias

### Useful Commands

`ash
# Check knowledge base status
aws bedrock-agent get-knowledge-base --knowledge-base-id 

# List ingestion jobs
aws bedrock-agent list-ingestion-jobs --knowledge-base-id 

# Check agent status
aws bedrock-agent get-agent --agent-id 
`

## Security Best Practices

1. Use least privilege IAM policies
2. Enable CloudTrail for API logging
3. Encrypt data at rest and in transit
4. Regularly rotate access keys
5. Monitor usage and costs

## Support

For issues with this Terraform configuration, please check:
1. AWS Bedrock documentation
2. Terraform AWS provider documentation
3. AWS support forums
