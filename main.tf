# AWS Bedrock Support Bot Terraform Configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Random string for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket for Knowledge Base Content
resource "aws_s3_bucket" "knowledge_base_bucket" {
  bucket = "${var.project_name}-kb-content-${random_string.suffix.result}"
}

resource "aws_s3_bucket_versioning" "knowledge_base_bucket_versioning" {
  bucket = aws_s3_bucket.knowledge_base_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "knowledge_base_bucket_encryption" {
  bucket = aws_s3_bucket.knowledge_base_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "knowledge_base_bucket_pab" {
  bucket = aws_s3_bucket.knowledge_base_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for Bedrock Knowledge Base
resource "aws_iam_role" "bedrock_kb_role" {
  name = "${var.project_name}-bedrock-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_kb_policy" {
  name = "${var.project_name}-bedrock-kb-policy"
  role = aws_iam_role.bedrock_kb_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.knowledge_base_bucket.arn,
          "${aws_s3_bucket.knowledge_base_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/*"
      },
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = aws_opensearchserverless_collection.knowledge_base_collection.arn
      }
    ]
  })
}
# Lambda function for fallback responses
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# Lambda function code
resource "aws_lambda_function" "fallback_function" {
  filename         = "fallback_function.zip"
  function_name    = "${var.project_name}-fallback-function"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30

  depends_on = [data.archive_file.lambda_zip]
}

# Create the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "fallback_function.zip"
  source {
    content = <<EOF
import json

def handler(event, context):
    # Extract the user's query from the event
    user_query = event.get('inputText', '')

    # You can add custom logic here based on the query
    # For now, return a generic fallback message

    response = {
        'messageVersion': '1.0',
        'response': {
            'actionGroup': event['actionGroup'],
            'function': event['function'],
            'functionResponse': {
                'responseBody': {
                    'TEXT': {
                        'body': "${var.lambda_fallback_message}"
                    }
                }
            }
        }
    }

    return response
EOF
    filename = "index.py"
  }
}

# Permission for Bedrock to invoke Lambda
resource "aws_lambda_permission" "allow_bedrock" {
  statement_id  = "AllowExecutionFromBedrock"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fallback_function.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:agent/*"
}

# IAM Role for Bedrock Agent
resource "aws_iam_role" "bedrock_agent_role" {
  name = "${var.project_name}-bedrock-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_agent_policy" {
  name = "${var.project_name}-bedrock-agent-policy"
  role = aws_iam_role.bedrock_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = aws_bedrockagent_knowledge_base.support_kb.arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.fallback_function.arn
      }
    ]
  })
}

# OpenSearch Serverless Collection for Knowledge Base
resource "aws_opensearchserverless_security_policy" "knowledge_base_encryption" {
  name = "${var.project_name}-kb-encryption"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/${var.project_name}-kb-collection"
        ]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "knowledge_base_network" {
  name = "${var.project_name}-kb-network"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          Resource = [
            "collection/${var.project_name}-kb-collection"
          ]
          ResourceType = "collection"
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "knowledge_base_access" {
  name = "${var.project_name}-kb-access"
  type = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          Resource = [
            "collection/${var.project_name}-kb-collection"
          ]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
          ResourceType = "collection"
        },
        {
          Resource = [
            "index/${var.project_name}-kb-collection/*"
          ]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
          ResourceType = "index"
        }
      ]
      Principal = [
        aws_iam_role.bedrock_kb_role.arn,
        aws_iam_role.bedrock_agent_role.arn
      ]
    }
  ])
}

resource "aws_opensearchserverless_collection" "knowledge_base_collection" {
  name = "${var.project_name}-kb-collection"
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.knowledge_base_encryption,
    aws_opensearchserverless_security_policy.knowledge_base_network,
    aws_opensearchserverless_access_policy.knowledge_base_access
  ]
}

# Create OpenSearch index before Knowledge Base
resource "null_resource" "create_opensearch_index" {
  depends_on = [aws_opensearchserverless_collection.knowledge_base_collection]

  provisioner "local-exec" {
    command = <<-EOT
      python3 -c "
import boto3, requests, json, time
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

print('Creating OpenSearch index...')

# Wait for collection to be fully ready
time.sleep(30)

client = boto3.client('opensearchserverless', region_name='us-east-1')
response = client.batch_get_collection(ids=['${aws_opensearchserverless_collection.knowledge_base_collection.id}'])
endpoint = response['collectionDetails'][0]['collectionEndpoint']

print(f'Collection endpoint: {endpoint}')

index_body = {
    'settings': {
        'index': {
            'knn': True,
            'knn.algo_param.ef_search': 512,
            'knn.algo_param.ef_construction': 512
        }
    },
    'mappings': {
        'properties': {
            'vector': {
                'type': 'knn_vector',
                'dimension': 1536,
                'method': {
                    'name': 'hnsw',
                    'engine': 'nmslib',
                    'parameters': {
                        'ef_construction': 512,
                        'm': 16
                    }
                }
            },
            'text': {'type': 'text'},
            'metadata': {'type': 'text'}
        }
    }
}

url = f'{endpoint}/vector-index'
request = AWSRequest(method='PUT', url=url, data=json.dumps(index_body), headers={'Content-Type': 'application/json'})
SigV4Auth(boto3.Session().get_credentials(), 'aoss', 'us-east-1').add_auth(request)
response = requests.put(url, data=request.body, headers=dict(request.headers))
print(f'Index creation status: {response.status_code}')
if response.status_code in [200, 201]:
    print('✅ Index created successfully!')
else:
    print(f'❌ Error: {response.text}')
    exit(1)
"
    EOT
  }
}

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "support_kb" {
  name     = "${var.project_name}-support-kb"
  role_arn = aws_iam_role.bedrock_kb_role.arn

  depends_on = [
    aws_opensearchserverless_collection.knowledge_base_collection,
    aws_opensearchserverless_access_policy.knowledge_base_access,
    null_resource.create_opensearch_index
  ]

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v1"
    }
    type = "VECTOR"
  }

  storage_configuration {
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.knowledge_base_collection.arn
      vector_index_name = "vector-index"
      field_mapping {
        vector_field   = "vector"
        text_field     = "text"
        metadata_field = "metadata"
      }
    }
    type = "OPENSEARCH_SERVERLESS"
  }
}

# Data Source for Knowledge Base
resource "aws_bedrockagent_data_source" "support_data_source" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.support_kb.id
  name              = "${var.project_name}-data-source"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.knowledge_base_bucket.arn
    }
  }
}

# Bedrock Agent
resource "aws_bedrockagent_agent" "support_agent" {
  agent_name                  = "${var.project_name}-support-agent"
  agent_resource_role_arn     = aws_iam_role.bedrock_agent_role.arn
  foundation_model            = var.foundation_model
  instruction                 = "You are a helpful support assistant. Use the knowledge base to answer user questions. If you cannot find the answer in the knowledge base, use the fallback action to provide a helpful response."

  depends_on = [
    aws_bedrockagent_knowledge_base.support_kb,
    aws_lambda_function.fallback_function
  ]
}

# Action Group for Lambda fallback
resource "aws_bedrockagent_agent_action_group" "fallback_action_group" {
  action_group_name = "fallback-action-group"
  agent_id          = aws_bedrockagent_agent.support_agent.id
  agent_version     = "DRAFT"

  action_group_executor {
    lambda = aws_lambda_function.fallback_function.arn
  }

  api_schema {
    payload = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Fallback API"
        version = "1.0.0"
      }
      paths = {
        "/fallback" = {
          post = {
            description = "Fallback function when knowledge base cannot answer"
            parameters = []
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      query = {
                        type        = "string"
                        description = "User's query"
                      }
                    }
                  }
                }
              }
            }
            responses = {
              "200" = {
                description = "Successful response"
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        response = {
                          type        = "string"
                          description = "Fallback response"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}

# Associate Knowledge Base with Agent
resource "aws_bedrockagent_agent_knowledge_base_association" "support_kb_association" {
  agent_id              = aws_bedrockagent_agent.support_agent.id
  agent_version         = "DRAFT"
  knowledge_base_id     = aws_bedrockagent_knowledge_base.support_kb.id
  knowledge_base_state  = "ENABLED"
  description          = "Support knowledge base for the agent"
}
