# Load environment variables from .env file
# Usage: . .\load-env.ps1

Write-Host "🔧 Loading environment variables from .env file..." -ForegroundColor Green

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^\s*([^#][^=]*)\s*=\s*(.*)\s*$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # Remove quotes if present
            if ($value -match '^"(.*)"$') {
                $value = $matches[1]
            }
            
            # Set environment variable
            Set-Item -Path "env:$name" -Value $value
            Write-Host "✅ Set $name" -ForegroundColor Cyan
        }
    }
    Write-Host "🎉 Environment variables loaded successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ .env file not found!" -ForegroundColor Red
    exit 1
}

# Display current AWS configuration
Write-Host "`n📋 Current AWS Configuration:" -ForegroundColor Yellow
Write-Host "AWS_PROFILE: $env:AWS_PROFILE" -ForegroundColor Cyan
Write-Host "AWS_DEFAULT_REGION: $env:AWS_DEFAULT_REGION" -ForegroundColor Cyan
