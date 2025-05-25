# Quick cleanup for most expensive resources
# Run this IMMEDIATELY after testing to minimize costs

Write-Host "🚨 EMERGENCY: Deleting most expensive resources first!" -ForegroundColor Red

# 1. OpenSearch Serverless Collection (HIGHEST COST - ~$700/month)
Write-Host "🔍 Deleting OpenSearch Serverless Collection..." -ForegroundColor Red
aws opensearchserverless list-collections --query "collectionSummaries[?contains(name, 'bedrock') || contains(name, 'support')].id" --output text | ForEach-Object {
    if ($_.Trim()) {
        Write-Host "Deleting collection: $_"
        aws opensearchserverless delete-collection --id $_
    }
}

# 2. Bedrock Agent (MEDIUM COST - per invocation)
Write-Host "🤖 Deleting Bedrock Agents..." -ForegroundColor Yellow
aws bedrock-agent list-agents --query "agentSummaries[?contains(agentName, 'bedrock') || contains(agentName, 'support')].agentId" --output text | ForEach-Object {
    if ($_.Trim()) {
        Write-Host "Deleting agent: $_"
        aws bedrock-agent delete-agent --agent-id $_ --skip-resource-in-use-check
    }
}

# 3. Knowledge Base (MEDIUM COST)
Write-Host "📚 Deleting Knowledge Bases..." -ForegroundColor Yellow
aws bedrock-agent list-knowledge-bases --query "knowledgeBaseSummaries[?contains(name, 'bedrock') || contains(name, 'support')].knowledgeBaseId" --output text | ForEach-Object {
    if ($_.Trim()) {
        Write-Host "Deleting knowledge base: $_"
        aws bedrock-agent delete-knowledge-base --knowledge-base-id $_
    }
}

Write-Host "✅ Most expensive resources deleted!" -ForegroundColor Green
Write-Host "💡 Run full cleanup script or 'terraform destroy' to remove remaining resources" -ForegroundColor Cyan
