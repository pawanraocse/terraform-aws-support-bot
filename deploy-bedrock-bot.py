#!/usr/bin/env python3
"""
AWS Bedrock Support Bot Deployment Script
Pure Python implementation using boto3 - bypasses Terraform limitations
"""

import boto3
import json
import time
import zipfile
import io
from botocore.exceptions import ClientError

# Configuration
PROJECT_NAME = "bedrock-support-bot"
REGION = "us-east-1"
FOUNDATION_MODEL = "amazon.titan-text-premier-v1:0"

# Initialize AWS clients
session = boto3.Session(region_name=REGION)
s3 = session.client('s3')
iam = session.client('iam')
lambda_client = session.client('lambda')
bedrock_agent = session.client('bedrock-agent')
sts = session.client('sts')

def print_status(message):
    print(f"✅ {message}")

def print_error(message):
    print(f"❌ {message}")

def print_info(message):
    print(f"ℹ️  {message}")

def get_account_id():
    """Get AWS account ID"""
    return sts.get_caller_identity()['Account']

def create_s3_bucket():
    """Create S3 bucket for knowledge base content"""
    print_info("Creating S3 bucket...")

    account_id = get_account_id()
    bucket_name = f"{PROJECT_NAME}-kb-content-{account_id}"

    try:
        s3.create_bucket(Bucket=bucket_name)

        # Configure bucket settings
        s3.put_bucket_versioning(
            Bucket=bucket_name,
            VersioningConfiguration={'Status': 'Enabled'}
        )

        s3.put_bucket_encryption(
            Bucket=bucket_name,
            ServerSideEncryptionConfiguration={
                'Rules': [{
                    'ApplyServerSideEncryptionByDefault': {
                        'SSEAlgorithm': 'AES256'
                    }
                }]
            }
        )

        s3.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': True,
                'IgnorePublicAcls': True,
                'BlockPublicPolicy': True,
                'RestrictPublicBuckets': True
            }
        )

        print_status(f"S3 bucket created: {bucket_name}")
        return bucket_name

    except ClientError as e:
        if e.response['Error']['Code'] == 'BucketAlreadyOwnedByYou':
            print_status(f"S3 bucket already exists: {bucket_name}")
            return bucket_name
        else:
            print_error(f"Failed to create S3 bucket: {e}")
            raise

def create_iam_role(role_name, assume_role_policy, description):
    """Create IAM role"""
    try:
        response = iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(assume_role_policy),
            Description=description
        )
        print_status(f"IAM role created: {role_name}")
        return response['Role']['Arn']
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            response = iam.get_role(RoleName=role_name)
            print_status(f"IAM role already exists: {role_name}")
            return response['Role']['Arn']
        else:
            print_error(f"Failed to create IAM role {role_name}: {e}")
            raise

def create_lambda_function():
    """Create Lambda function for fallback responses"""
    print_info("Creating Lambda function...")

    # Create Lambda execution role
    lambda_role_policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "lambda.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }

    lambda_role_arn = create_iam_role(
        f"{PROJECT_NAME}-lambda-role",
        lambda_role_policy,
        "Lambda execution role for Bedrock support bot"
    )

    # Attach basic execution policy
    try:
        iam.attach_role_policy(
            RoleName=f"{PROJECT_NAME}-lambda-role",
            PolicyArn="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        )
    except ClientError as e:
        if e.response['Error']['Code'] != 'EntityAlreadyExists':
            print_error(f"Failed to attach Lambda policy: {e}")

    # Wait for IAM role to propagate
    print_info("Waiting for IAM role to propagate...")
    time.sleep(15)

    # Create Lambda function code
    lambda_code = '''
def handler(event, context):
    return {
        'statusCode': 200,
        'body': {
            'application/json': {
                'body': 'I apologize, but I could not find relevant information in our knowledge base to answer your question. Please contact our support team for further assistance.'
            }
        }
    }
'''

    # Create ZIP file in memory
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
        zip_file.writestr('lambda_function.py', lambda_code)
    zip_buffer.seek(0)

    function_name = f"{PROJECT_NAME}-fallback-function"

    try:
        response = lambda_client.create_function(
            FunctionName=function_name,
            Runtime='python3.9',
            Role=lambda_role_arn,
            Handler='lambda_function.handler',
            Code={'ZipFile': zip_buffer.read()},
            Description='Fallback function for Bedrock support bot',
            Timeout=30
        )

        # Add permission for Bedrock to invoke Lambda
        lambda_client.add_permission(
            FunctionName=function_name,
            StatementId='AllowBedrockInvoke',
            Action='lambda:InvokeFunction',
            Principal='bedrock.amazonaws.com',
            SourceArn=f"arn:aws:bedrock:{REGION}:{get_account_id()}:agent/*"
        )

        print_status(f"Lambda function created: {function_name}")
        return response['FunctionArn']

    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceConflictException':
            response = lambda_client.get_function(FunctionName=function_name)
            print_status(f"Lambda function already exists: {function_name}")
            return response['Configuration']['FunctionArn']
        else:
            print_error(f"Failed to create Lambda function: {e}")
            raise

def create_bedrock_agent(lambda_arn):
    """Create Bedrock Agent without Knowledge Base (simpler approach)"""
    print_info("Creating Bedrock Agent...")

    # Create Bedrock agent role
    agent_role_policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "bedrock.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }

    agent_role_arn = create_iam_role(
        f"{PROJECT_NAME}-agent-role",
        agent_role_policy,
        "Bedrock agent role for support bot"
    )

    # Create inline policy for agent
    agent_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": ["bedrock:InvokeModel"],
                "Resource": f"arn:aws:bedrock:{REGION}::foundation-model/*"
            },
            {
                "Effect": "Allow",
                "Action": ["lambda:InvokeFunction"],
                "Resource": lambda_arn
            }
        ]
    }

    try:
        iam.put_role_policy(
            RoleName=f"{PROJECT_NAME}-agent-role",
            PolicyName=f"{PROJECT_NAME}-agent-policy",
            PolicyDocument=json.dumps(agent_policy)
        )
    except ClientError as e:
        print_error(f"Failed to create agent policy: {e}")

    # Wait for role to propagate
    time.sleep(10)

    # Create Bedrock agent (without action groups first)
    try:
        response = bedrock_agent.create_agent(
            agentName=f"{PROJECT_NAME}-agent",
            agentResourceRoleArn=agent_role_arn,
            foundationModel=FOUNDATION_MODEL,
            instruction="You are a helpful support assistant. Answer user questions to the best of your ability."
        )

        agent_id = response['agent']['agentId']
        print_status(f"Bedrock agent created: {agent_id}")

        # Wait for agent to be ready
        print_info("Waiting for agent to be ready...")
        max_wait = 60  # Wait up to 60 seconds
        for i in range(max_wait):
            try:
                agent_response = bedrock_agent.get_agent(agentId=agent_id)
                agent_status = agent_response['agent']['agentStatus']
                print_info(f"Agent status: {agent_status}")

                if agent_status == 'NOT_PREPARED':
                    print_status("Agent is ready for configuration")
                    break
                elif agent_status in ['FAILED', 'DELETING']:
                    print_error(f"Agent creation failed with status: {agent_status}")
                    raise Exception(f"Agent creation failed: {agent_status}")
                else:
                    time.sleep(2)
            except ClientError as e:
                print_error(f"Error checking agent status: {e}")
                time.sleep(2)

        # Create action group separately (optional)
        print_info("Creating action group...")
        try:
            bedrock_agent.create_agent_action_group(
                agentId=agent_id,
                agentVersion='DRAFT',
                actionGroupName='fallback-action',
                description='Fallback action when no answer is found',
                actionGroupExecutor={
                    'lambda': lambda_arn
                },
                apiSchema={
                    'payload': json.dumps({
                        "openapi": "3.0.0",
                        "info": {"title": "Fallback API", "version": "1.0.0"},
                        "paths": {
                            "/fallback": {
                                "post": {
                                    "description": "Fallback response when no answer found",
                                    "responses": {"200": {"description": "Fallback response"}}
                                }
                            }
                        }
                    })
                }
            )
            print_status("Action group created")
        except ClientError as e:
            print_error(f"Failed to create action group: {e}")
            print_info("Agent will work without action group")

        # Prepare agent
        print_info("Preparing agent...")
        try:
            bedrock_agent.prepare_agent(agentId=agent_id)
            print_status("Agent prepared successfully")
        except ClientError as e:
            print_error(f"Failed to prepare agent: {e}")
            print_info("Agent can still be used in DRAFT mode")

        return agent_id

    except ClientError as e:
        print_error(f"Failed to create Bedrock agent: {e}")
        raise

def main():
    """Main deployment function"""
    print("🚀 Deploying AWS Bedrock Support Bot (Python SDK)")
    print("=" * 50)

    try:
        # Create S3 bucket
        bucket_name = create_s3_bucket()

        # Create Lambda function
        lambda_arn = create_lambda_function()

        # Create Bedrock agent (without Knowledge Base for now)
        agent_id = create_bedrock_agent(lambda_arn)

        print("\n" + "=" * 50)
        print_status("Deployment completed successfully!")
        print(f"S3 Bucket: {bucket_name}")
        print(f"Lambda Function: {lambda_arn}")
        print(f"Bedrock Agent ID: {agent_id}")

        print("\n🧪 Testing the agent...")
        print("You can test the agent using:")
        print(f"aws bedrock-agent-runtime invoke-agent --agent-id {agent_id} --agent-alias-id TSTALIASID --session-id test --input-text 'Hello'")

        print("\n🗑️  To clean up:")
        print("Run the cleanup script when done testing")

    except Exception as e:
        print_error(f"Deployment failed: {e}")
        raise

if __name__ == "__main__":
    main()
