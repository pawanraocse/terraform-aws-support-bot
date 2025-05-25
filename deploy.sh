#!/bin/bash
# Deployment script for AWS Bedrock Support Bot

echo "Deploying AWS Bedrock Support Bot..."

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Plan deployment
echo "Planning deployment..."
terraform plan

# Apply configuration
echo "Applying configuration..."
terraform apply -auto-approve

# Get outputs
echo "Deployment complete! Here are the important outputs:"
echo "S3 Bucket: $(terraform output -raw s3_bucket_name)"
echo "Knowledge Base ID: $(terraform output -raw knowledge_base_id)"
echo "Agent ID: $(terraform output -raw agent_id)"

echo ""
echo "Next steps:"
echo "1. Upload your documents to the S3 bucket"
echo "2. Start an ingestion job for the knowledge base"
echo "3. Prepare the agent"
echo "4. Test the agent"
