# Validation script for Terraform configuration

Write-Host "Validating Terraform configuration..." -ForegroundColor Green

# Initialize Terraform (required for validation)
Write-Host "Initializing Terraform..." -ForegroundColor Yellow
terraform init

# Validate configuration
Write-Host "Validating configuration..." -ForegroundColor Yellow
terraform validate

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Terraform configuration is valid!" -ForegroundColor Green
} else {
    Write-Host "❌ Terraform configuration has errors!" -ForegroundColor Red
}

# Format check
Write-Host "Checking formatting..." -ForegroundColor Yellow
terraform fmt -check

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Terraform files are properly formatted!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some files need formatting. Run 'terraform fmt' to fix." -ForegroundColor Yellow
}
