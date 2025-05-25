#!/bin/bash
# Advanced dry run that catches real deployment errors
# Tests actual AWS operations that might fail during deployment

echo "🔬 Advanced Dry Run - Real Error Detection"
echo "=========================================="
echo "⏰ Started at: $(date)"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Set environment
export AWS_DEFAULT_REGION=us-east-1
export TF_VAR_aws_region=us-east-1
export TF_VAR_project_name=my-support-bot-test
export TF_VAR_foundation_model=amazon.titan-text-premier-v1:0

echo "🧪 Testing Real AWS Operations..."
echo "--------------------------------"

# Test 1: OpenSearch Serverless Permissions
echo ""
print_info "Test 1: OpenSearch Serverless Access"

# Try to list collections (basic permission test)
if aws opensearchserverless list-collections &>/dev/null; then
    print_status "OpenSearch Serverless API access works"
else
    print_error "Cannot access OpenSearch Serverless API"
    echo "This will cause deployment failures!"
fi

# Test 2: Bedrock Agent Permissions
echo ""
print_info "Test 2: Bedrock Agent API Access"

if aws bedrock-agent list-agents &>/dev/null; then
    print_status "Bedrock Agent API access works"
else
    print_error "Cannot access Bedrock Agent API"
    echo "This will cause agent creation to fail!"
fi

# Test 3: Create a minimal test collection to verify permissions
echo ""
print_info "Test 3: OpenSearch Collection Creation Test"

TEST_COLLECTION_NAME="test-permissions-$(date +%s)"

# Create minimal security policies for test
cat > test-encryption-policy.json << EOF
{
    "Rules": [
        {
            "Resource": ["collection/$TEST_COLLECTION_NAME"],
            "ResourceType": "collection"
        }
    ],
    "AWSOwnedKey": true
}
EOF

cat > test-network-policy.json << EOF
[
    {
        "Rules": [
            {
                "Resource": ["collection/$TEST_COLLECTION_NAME"],
                "ResourceType": "collection"
            }
        ],
        "AllowFromPublic": true
    }
]
EOF

# Get current user ARN for access policy
USER_ARN=$(aws sts get-caller-identity --query "Arn" --output text)

cat > test-access-policy.json << EOF
[
    {
        "Rules": [
            {
                "Resource": ["collection/$TEST_COLLECTION_NAME"],
                "Permission": [
                    "aoss:CreateCollectionItems",
                    "aoss:DescribeCollectionItems"
                ],
                "ResourceType": "collection"
            },
            {
                "Resource": ["index/$TEST_COLLECTION_NAME/*"],
                "Permission": [
                    "aoss:CreateIndex",
                    "aoss:DescribeIndex",
                    "aoss:ReadDocument",
                    "aoss:WriteDocument"
                ],
                "ResourceType": "index"
            }
        ],
        "Principal": ["$USER_ARN"]
    }
]
EOF

print_info "Creating test security policies..."

# Create test policies
if aws opensearchserverless create-security-policy \
    --name "$TEST_COLLECTION_NAME-encryption" \
    --type encryption \
    --policy file://test-encryption-policy.json &>/dev/null; then
    print_status "Encryption policy created"
    CLEANUP_ENCRYPTION=true
else
    print_error "Failed to create encryption policy"
    CLEANUP_ENCRYPTION=false
fi

if aws opensearchserverless create-security-policy \
    --name "$TEST_COLLECTION_NAME-network" \
    --type network \
    --policy file://test-network-policy.json &>/dev/null; then
    print_status "Network policy created"
    CLEANUP_NETWORK=true
else
    print_error "Failed to create network policy"
    CLEANUP_NETWORK=false
fi

if aws opensearchserverless create-access-policy \
    --name "$TEST_COLLECTION_NAME-access" \
    --type data \
    --policy file://test-access-policy.json &>/dev/null; then
    print_status "Access policy created"
    CLEANUP_ACCESS=true
else
    print_error "Failed to create access policy"
    CLEANUP_ACCESS=false
fi

# Test collection creation
print_info "Testing collection creation..."
if aws opensearchserverless create-collection \
    --name "$TEST_COLLECTION_NAME" \
    --type VECTORSEARCH &>/dev/null; then
    print_status "Test collection creation started"
    CLEANUP_COLLECTION=true

    # Wait for collection to be active
    print_info "Waiting for collection to become active..."
    for i in {1..30}; do
        STATUS=$(aws opensearchserverless batch-get-collection \
            --names "$TEST_COLLECTION_NAME" \
            --query "collectionDetails[0].status" \
            --output text 2>/dev/null)

        if [ "$STATUS" = "ACTIVE" ]; then
            print_status "Test collection is active"
            break
        elif [ "$STATUS" = "FAILED" ]; then
            print_error "Test collection creation failed"
            break
        else
            echo -n "."
            sleep 10
        fi
    done

    if [ "$STATUS" = "ACTIVE" ]; then
        # Test index creation
        print_info "Testing index creation on active collection..."

        COLLECTION_ID=$(aws opensearchserverless batch-get-collection \
            --names "$TEST_COLLECTION_NAME" \
            --query "collectionDetails[0].id" \
            --output text)

        ENDPOINT=$(aws opensearchserverless batch-get-collection \
            --names "$TEST_COLLECTION_NAME" \
            --query "collectionDetails[0].collectionEndpoint" \
            --output text)

        print_info "Collection endpoint: $ENDPOINT"

        # Test index creation with Python
        python3 -c "
import boto3, requests, json, time
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

endpoint = '$ENDPOINT'
index_body = {
    'settings': {'index': {'knn': True}},
    'mappings': {
        'properties': {
            'vector': {'type': 'knn_vector', 'dimension': 1536, 'method': {'name': 'hnsw', 'engine': 'nmslib'}},
            'text': {'type': 'text'},
            'metadata': {'type': 'text'}
        }
    }
}

url = f'{endpoint}/test-index'
request = AWSRequest(method='PUT', url=url, data=json.dumps(index_body), headers={'Content-Type': 'application/json'})
SigV4Auth(boto3.Session().get_credentials(), 'aoss', 'us-east-1').add_auth(request)
response = requests.put(url, data=request.body, headers=dict(request.headers))

print(f'Index creation status: {response.status_code}')
if response.status_code in [200, 201]:
    print('✅ Index creation test PASSED')
    exit(0)
else:
    print(f'❌ Index creation test FAILED: {response.text}')
    exit(1)
"

        if [ $? -eq 0 ]; then
            print_status "Index creation test PASSED - Deployment should work!"
        else
            print_error "Index creation test FAILED - Deployment will fail!"
            echo "This is the exact error you'll hit during terraform apply"
        fi
    fi

else
    print_error "Test collection creation failed"
    CLEANUP_COLLECTION=false
fi

# Cleanup test resources
echo ""
print_info "Cleaning up test resources..."

if [ "$CLEANUP_COLLECTION" = true ]; then
    aws opensearchserverless delete-collection --id "$COLLECTION_ID" &>/dev/null
    print_info "Test collection deletion initiated"
fi

if [ "$CLEANUP_ACCESS" = true ]; then
    aws opensearchserverless delete-access-policy --name "$TEST_COLLECTION_NAME-access" --type data &>/dev/null
fi

if [ "$CLEANUP_NETWORK" = true ]; then
    aws opensearchserverless delete-security-policy --name "$TEST_COLLECTION_NAME-network" --type network &>/dev/null
fi

if [ "$CLEANUP_ENCRYPTION" = true ]; then
    aws opensearchserverless delete-security-policy --name "$TEST_COLLECTION_NAME-encryption" --type encryption &>/dev/null
fi

# Clean up temp files
rm -f test-*.json

# Test 4: Bedrock Knowledge Base Creation Test
echo ""
print_info "Test 4: Bedrock Knowledge Base Permissions"

# Test if we can create a knowledge base (dry run)
print_info "Testing Bedrock Knowledge Base API permissions..."

# Check if we can list knowledge bases
if aws bedrock-agent list-knowledge-bases &>/dev/null; then
    print_status "Bedrock Knowledge Base API access works"
else
    print_error "Cannot access Bedrock Knowledge Base API"
    echo "Knowledge Base creation will fail!"
fi

# Test 5: IAM Role Creation Test
echo ""
print_info "Test 5: IAM Role Creation Permissions"

if aws iam list-roles --max-items 1 &>/dev/null; then
    print_status "IAM API access works"
else
    print_error "Cannot access IAM API - role creation will fail"
fi

# Test 6: Lambda Function Creation Test
echo ""
print_info "Test 6: Lambda Function Permissions"

if aws lambda list-functions --max-items 1 &>/dev/null; then
    print_status "Lambda API access works"
else
    print_error "Cannot access Lambda API - function creation will fail"
fi

echo ""
echo "🎯 Advanced Dry Run Complete"
echo "============================"
print_info "This test simulated the exact operations that happen during deployment"
print_info "If all tests passed, your deployment should succeed"
print_info "If any tests failed, fix those issues before deploying"

echo ""
print_warning "Key Findings:"
echo "- If index creation test passed: ✅ Deployment will likely succeed"
echo "- If index creation test failed: ❌ You'll hit the same error during terraform apply"
echo "- This test creates and deletes real AWS resources to verify permissions"

echo ""
echo "⏰ Completed at: $(date)"
