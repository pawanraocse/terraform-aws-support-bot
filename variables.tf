variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "bedrock-support-bot"
}

variable "foundation_model" {
  description = "Foundation model for the Bedrock agent"
  type        = string
  default     = "amazon.titan-text-premier-v1:0"
}

variable "lambda_fallback_message" {
  description = "Default fallback message for Lambda function"
  type        = string
  default     = "I'm sorry, I couldn't find an answer to your question in our knowledge base. Please contact our support team for further assistance."
}
