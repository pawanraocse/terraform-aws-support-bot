output "s3_bucket_name" {
  description = "Name of the S3 bucket for knowledge base content"
  value       = aws_s3_bucket.knowledge_base_bucket.bucket
}

output "knowledge_base_id" {
  description = "ID of the Bedrock knowledge base"
  value       = aws_bedrockagent_knowledge_base.support_kb.id
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock knowledge base"
  value       = aws_bedrockagent_knowledge_base.support_kb.arn
}

output "agent_id" {
  description = "ID of the Bedrock agent"
  value       = aws_bedrockagent_agent.support_agent.id
}

output "agent_arn" {
  description = "ARN of the Bedrock agent"
  value       = aws_bedrockagent_agent.support_agent.agent_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda fallback function"
  value       = aws_lambda_function.fallback_function.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda fallback function"
  value       = aws_lambda_function.fallback_function.arn
}

output "opensearch_collection_endpoint" {
  description = "Endpoint of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.knowledge_base_collection.collection_endpoint
}
