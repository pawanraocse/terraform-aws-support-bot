# Emergency cleanup script for AWS Bedrock Support Bot
# Use this if terraform destroy fails

Write-Host "🧹 Emergency cleanup for AWS Bedrock Support Bot..." -ForegroundColor Red
Write-Host "⚠️  This will delete resources manually. Use with caution!" -ForegroundColor Yellow

# Get project name from terraform.tfvars or use default
$projectName = "bedrock-support-bot"
if (Test-Path "terraform.tfvars") {
    $tfvars = Get-Content "terraform.tfvars"
    $projectNameLine = $tfvars | Where-Object { $_ -match 'project_name\s*=\s*"([^"]+)"' }
    if ($projectNameLine) {
        $projectName = $Matches[1]
    }
}

Write-Host "Using project name: $projectName" -ForegroundColor Cyan

# 1. Delete Bedrock Agent (most expensive to keep running)
Write-Host "🤖 Deleting Bedrock Agent..." -ForegroundColor Yellow
try {
    $agents = aws bedrock-agent list-agents --query "agentSummaries[?contains(agentName, '$projectName')].agentId" --output text
    if ($agents) {
        foreach ($agentId in $agents.Split()) {
            if ($agentId.Trim()) {
                Write-Host "Deleting agent: $agentId"
                aws bedrock-agent delete-agent --agent-id $agentId --skip-resource-in-use-check
            }
        }
    }
} catch {
    Write-Host "Error deleting agents: $_" -ForegroundColor Red
}

# 2. Delete Knowledge Base
Write-Host "📚 Deleting Knowledge Base..." -ForegroundColor Yellow
try {
    $kbs = aws bedrock-agent list-knowledge-bases --query "knowledgeBaseSummaries[?contains(name, '$projectName')].knowledgeBaseId" --output text
    if ($kbs) {
        foreach ($kbId in $kbs.Split()) {
            if ($kbId.Trim()) {
                Write-Host "Deleting knowledge base: $kbId"
                aws bedrock-agent delete-knowledge-base --knowledge-base-id $kbId
            }
        }
    }
} catch {
    Write-Host "Error deleting knowledge bases: $_" -ForegroundColor Red
}

# 3. Delete OpenSearch Serverless Collection (MOST EXPENSIVE!)
Write-Host "🔍 Deleting OpenSearch Serverless Collection..." -ForegroundColor Red
try {
    $collections = aws opensearchserverless list-collections --query "collectionSummaries[?contains(name, '$projectName')].id" --output text
    if ($collections) {
        foreach ($collectionId in $collections.Split()) {
            if ($collectionId.Trim()) {
                Write-Host "Deleting collection: $collectionId"
                aws opensearchserverless delete-collection --id $collectionId
            }
        }
    }
} catch {
    Write-Host "Error deleting collections: $_" -ForegroundColor Red
}

# 4. Delete OpenSearch Serverless Policies
Write-Host "🔒 Deleting OpenSearch Serverless Policies..." -ForegroundColor Yellow
try {
    # Delete access policies
    $accessPolicies = aws opensearchserverless list-access-policies --type data --query "accessPolicySummaries[?contains(name, '$projectName')].name" --output text
    if ($accessPolicies) {
        foreach ($policyName in $accessPolicies.Split()) {
            if ($policyName.Trim()) {
                aws opensearchserverless delete-access-policy --name $policyName --type data
            }
        }
    }
    
    # Delete security policies
    aws opensearchserverless delete-security-policy --name "$projectName-kb-encryption" --type encryption
    aws opensearchserverless delete-security-policy --name "$projectName-kb-network" --type network
} catch {
    Write-Host "Error deleting policies: $_" -ForegroundColor Red
}

# 5. Delete Lambda Function
Write-Host "⚡ Deleting Lambda Function..." -ForegroundColor Yellow
try {
    aws lambda delete-function --function-name "$projectName-fallback-function"
} catch {
    Write-Host "Error deleting Lambda function: $_" -ForegroundColor Red
}

# 6. Delete S3 Bucket (empty it first)
Write-Host "🪣 Deleting S3 Bucket..." -ForegroundColor Yellow
try {
    $buckets = aws s3api list-buckets --query "Buckets[?contains(Name, '$projectName')].Name" --output text
    if ($buckets) {
        foreach ($bucketName in $buckets.Split()) {
            if ($bucketName.Trim()) {
                Write-Host "Emptying and deleting bucket: $bucketName"
                aws s3 rm s3://$bucketName --recursive
                aws s3api delete-bucket --bucket $bucketName
            }
        }
    }
} catch {
    Write-Host "Error deleting S3 bucket: $_" -ForegroundColor Red
}

# 7. Delete IAM Roles and Policies
Write-Host "🔐 Deleting IAM Roles..." -ForegroundColor Yellow
try {
    $roles = @(
        "$projectName-bedrock-kb-role",
        "$projectName-lambda-execution-role", 
        "$projectName-bedrock-agent-role"
    )
    
    foreach ($roleName in $roles) {
        # Detach policies first
        $attachedPolicies = aws iam list-attached-role-policies --role-name $roleName --query "AttachedPolicies[].PolicyArn" --output text 2>$null
        if ($attachedPolicies) {
            foreach ($policyArn in $attachedPolicies.Split()) {
                if ($policyArn.Trim()) {
                    aws iam detach-role-policy --role-name $roleName --policy-arn $policyArn
                }
            }
        }
        
        # Delete inline policies
        $inlinePolicies = aws iam list-role-policies --role-name $roleName --query "PolicyNames" --output text 2>$null
        if ($inlinePolicies) {
            foreach ($policyName in $inlinePolicies.Split()) {
                if ($policyName.Trim()) {
                    aws iam delete-role-policy --role-name $roleName --policy-name $policyName
                }
            }
        }
        
        # Delete role
        aws iam delete-role --role-name $roleName 2>$null
    }
} catch {
    Write-Host "Error deleting IAM roles: $_" -ForegroundColor Red
}

Write-Host "✅ Cleanup complete!" -ForegroundColor Green
Write-Host "💡 Tip: Run 'terraform destroy' first next time for cleaner removal" -ForegroundColor Cyan
