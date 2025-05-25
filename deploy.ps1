# PowerShell deployment script for AWS Bedrock Support Bot

Write-Host "Deploying AWS Bedrock Support Bot..." -ForegroundColor Green

# Initialize Terraform
Write-Host "Initializing Terraform..." -ForegroundColor Yellow
terraform init

# Plan deployment
Write-Host "Planning deployment..." -ForegroundColor Yellow
terraform plan

# Apply configuration
Write-Host "Applying configuration..." -ForegroundColor Yellow
terraform apply -auto-approve

# Get outputs
Write-Host "Deployment complete! Here are the important outputs:" -ForegroundColor Green
Write-Host "S3 Bucket: $(terraform output -raw s3_bucket_name)" -ForegroundColor Cyan
Write-Host "Knowledge Base ID: $(terraform output -raw knowledge_base_id)" -ForegroundColor Cyan
Write-Host "Agent ID: $(terraform output -raw agent_id)" -ForegroundColor Cyan

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Upload your documents to the S3 bucket"
Write-Host "2. Start an ingestion job for the knowledge base"
Write-Host "3. Prepare the agent"
Write-Host "4. Test the agent"
