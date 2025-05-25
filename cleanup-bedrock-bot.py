#!/usr/bin/env python3
"""
Cleanup script for AWS Bedrock Support Bot
Removes all resources created by the deployment script
"""

import boto3
import time
from botocore.exceptions import ClientError

# Configuration
PROJECT_NAME = "bedrock-support-bot"
REGION = "us-east-1"

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

def delete_bedrock_agent():
    """Delete Bedrock agent"""
    print_info("Deleting Bedrock agent...")
    
    try:
        # List agents to find ours
        response = bedrock_agent.list_agents()
        for agent in response.get('agentSummaries', []):
            if PROJECT_NAME in agent['agentName']:
                agent_id = agent['agentId']
                print_info(f"Found agent: {agent_id}")
                
                try:
                    bedrock_agent.delete_agent(
                        agentId=agent_id,
                        skipResourceInUseCheck=True
                    )
                    print_status(f"Deleted agent: {agent_id}")
                except ClientError as e:
                    print_error(f"Failed to delete agent {agent_id}: {e}")
                    
    except ClientError as e:
        print_error(f"Failed to list/delete agents: {e}")

def delete_lambda_function():
    """Delete Lambda function"""
    print_info("Deleting Lambda function...")
    
    function_name = f"{PROJECT_NAME}-fallback-function"
    
    try:
        lambda_client.delete_function(FunctionName=function_name)
        print_status(f"Deleted Lambda function: {function_name}")
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            print_info(f"Lambda function {function_name} not found")
        else:
            print_error(f"Failed to delete Lambda function: {e}")

def delete_iam_roles():
    """Delete IAM roles"""
    print_info("Deleting IAM roles...")
    
    roles = [
        f"{PROJECT_NAME}-lambda-role",
        f"{PROJECT_NAME}-agent-role"
    ]
    
    for role_name in roles:
        try:
            # Detach managed policies
            try:
                attached_policies = iam.list_attached_role_policies(RoleName=role_name)
                for policy in attached_policies['AttachedPolicies']:
                    iam.detach_role_policy(
                        RoleName=role_name,
                        PolicyArn=policy['PolicyArn']
                    )
            except ClientError:
                pass
            
            # Delete inline policies
            try:
                inline_policies = iam.list_role_policies(RoleName=role_name)
                for policy_name in inline_policies['PolicyNames']:
                    iam.delete_role_policy(
                        RoleName=role_name,
                        PolicyName=policy_name
                    )
            except ClientError:
                pass
            
            # Delete role
            iam.delete_role(RoleName=role_name)
            print_status(f"Deleted IAM role: {role_name}")
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'NoSuchEntity':
                print_info(f"IAM role {role_name} not found")
            else:
                print_error(f"Failed to delete IAM role {role_name}: {e}")

def delete_s3_bucket():
    """Delete S3 bucket"""
    print_info("Deleting S3 bucket...")
    
    account_id = get_account_id()
    bucket_name = f"{PROJECT_NAME}-kb-content-{account_id}"
    
    try:
        # Empty bucket first
        try:
            response = s3.list_objects_v2(Bucket=bucket_name)
            if 'Contents' in response:
                objects = [{'Key': obj['Key']} for obj in response['Contents']]
                s3.delete_objects(
                    Bucket=bucket_name,
                    Delete={'Objects': objects}
                )
                print_info(f"Emptied bucket: {bucket_name}")
        except ClientError:
            pass
        
        # Delete bucket
        s3.delete_bucket(Bucket=bucket_name)
        print_status(f"Deleted S3 bucket: {bucket_name}")
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchBucket':
            print_info(f"S3 bucket {bucket_name} not found")
        else:
            print_error(f"Failed to delete S3 bucket: {e}")

def main():
    """Main cleanup function"""
    print("🗑️  Cleaning up AWS Bedrock Support Bot resources")
    print("=" * 50)
    
    # Delete in reverse order of creation
    delete_bedrock_agent()
    time.sleep(5)  # Wait for agent deletion to propagate
    
    delete_lambda_function()
    delete_iam_roles()
    delete_s3_bucket()
    
    print("\n" + "=" * 50)
    print_status("Cleanup completed!")
    print_info("All resources have been removed")

if __name__ == "__main__":
    main()
