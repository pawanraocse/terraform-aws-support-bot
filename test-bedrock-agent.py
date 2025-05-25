#!/usr/bin/env python3
"""
Test script for AWS Bedrock Support Bot
Tests the deployed agent with various queries
"""

import boto3
import json
import time
import uuid
from botocore.exceptions import ClientError

# Configuration
REGION = "us-east-1"
PROFILE = "bedrock-user"  # Use your AWS profile
PROJECT_NAME = "bedrock-support-bot"

def print_status(message):
    print(f"✅ {message}")

def print_error(message):
    print(f"❌ {message}")

def print_info(message):
    print(f"ℹ️  {message}")

def print_test(message):
    print(f"🧪 {message}")

def get_bedrock_agent_id():
    """Find the Bedrock agent ID"""
    try:
        session = boto3.Session(profile_name=PROFILE, region_name=REGION)
        bedrock_agent = session.client('bedrock-agent')
        
        response = bedrock_agent.list_agents()
        
        for agent in response.get('agentSummaries', []):
            if PROJECT_NAME in agent['agentName']:
                return agent['agentId']
        
        print_error("No Bedrock agent found with project name")
        return None
        
    except ClientError as e:
        print_error(f"Failed to list agents: {e}")
        return None

def test_agent(agent_id, test_message, test_name):
    """Test the agent with a specific message"""
    try:
        session = boto3.Session(profile_name=PROFILE, region_name=REGION)
        bedrock_runtime = session.client('bedrock-agent-runtime')
        
        session_id = f"test-{uuid.uuid4().hex[:8]}"
        
        print_test(f"{test_name}")
        print(f"Query: {test_message}")
        
        response = bedrock_runtime.invoke_agent(
            agentId=agent_id,
            agentAliasId='TSTALIASID',
            sessionId=session_id,
            inputText=test_message
        )
        
        # Extract the completion from the response
        completion = ""
        if 'completion' in response:
            for event in response['completion']:
                if 'chunk' in event:
                    chunk = event['chunk']
                    if 'bytes' in chunk:
                        completion += chunk['bytes'].decode('utf-8')
        
        print(f"Response: {completion}")
        print("-" * 50)
        return True
        
    except ClientError as e:
        print_error(f"Failed to invoke agent: {e}")
        return False

def test_agent_simple(agent_id, test_message, test_name):
    """Simplified test method"""
    try:
        session = boto3.Session(profile_name=PROFILE, region_name=REGION)
        bedrock_runtime = session.client('bedrock-agent-runtime')
        
        session_id = f"test-{int(time.time())}"
        
        print_test(f"{test_name}")
        print(f"Query: {test_message}")
        
        response = bedrock_runtime.invoke_agent(
            agentId=agent_id,
            agentAliasId='TSTALIASID',
            sessionId=session_id,
            inputText=test_message
        )
        
        print(f"Raw Response: {json.dumps(response, indent=2, default=str)}")
        print("-" * 50)
        return True
        
    except ClientError as e:
        print_error(f"Failed to invoke agent: {e}")
        print(f"Error details: {e.response}")
        return False

def main():
    """Main test function"""
    print("🤖 Testing AWS Bedrock Support Bot")
    print("=" * 50)
    
    # Get agent ID
    print_info("Finding Bedrock agent...")
    agent_id = get_bedrock_agent_id()
    
    if not agent_id:
        print_error("Could not find agent. Make sure it's deployed.")
        return
    
    print_status(f"Found agent: {agent_id}")
    print("")
    
    # Test cases
    test_cases = [
        ("Hello, can you help me?", "Basic Greeting"),
        ("What services do you provide?", "Service Inquiry"),
        ("How do I reset my password?", "Technical Support"),
        ("I'm having trouble with my account", "Account Issue"),
        ("What's the weather like?", "Off-topic Question"),
        ("Can you help me troubleshoot an error?", "Troubleshooting Request")
    ]
    
    print_info(f"Running {len(test_cases)} test cases...")
    print("")
    
    successful_tests = 0
    
    for test_message, test_name in test_cases:
        if test_agent_simple(agent_id, test_message, test_name):
            successful_tests += 1
        time.sleep(2)  # Small delay between tests
    
    print("")
    print("=" * 50)
    print_status(f"Testing completed: {successful_tests}/{len(test_cases)} tests successful")
    
    if successful_tests == len(test_cases):
        print_status("🎉 All tests passed! Your Bedrock agent is working correctly.")
    else:
        print_error(f"Some tests failed. Check the error messages above.")

def interactive_test():
    """Interactive testing mode"""
    print("🤖 Interactive Bedrock Agent Test")
    print("=" * 40)
    
    agent_id = get_bedrock_agent_id()
    if not agent_id:
        print_error("Could not find agent.")
        return
    
    print_status(f"Connected to agent: {agent_id}")
    print_info("Type 'quit' to exit")
    print("")
    
    session_id = f"interactive-{int(time.time())}"
    
    while True:
        try:
            user_input = input("You: ").strip()
            
            if user_input.lower() in ['quit', 'exit', 'q']:
                print("Goodbye!")
                break
            
            if not user_input:
                continue
            
            session = boto3.Session(profile_name=PROFILE, region_name=REGION)
            bedrock_runtime = session.client('bedrock-agent-runtime')
            
            response = bedrock_runtime.invoke_agent(
                agentId=agent_id,
                agentAliasId='TSTALIASID',
                sessionId=session_id,
                inputText=user_input
            )
            
            print(f"Agent: {json.dumps(response, indent=2, default=str)}")
            print("")
            
        except KeyboardInterrupt:
            print("\nGoodbye!")
            break
        except Exception as e:
            print_error(f"Error: {e}")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "interactive":
        interactive_test()
    else:
        main()
