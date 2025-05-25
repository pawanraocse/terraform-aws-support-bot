#!/usr/bin/env python3
"""
Flask web server for AWS Bedrock Support Bot UI
Provides a web interface to interact with the Bedrock agent
"""

from flask import Flask, render_template, request, jsonify, send_from_directory
import boto3
import json
import uuid
import time
import os
from botocore.exceptions import ClientError

# Configuration
REGION = "us-east-1"
PROFILE = "bedrock-user"  # Your AWS profile
PROJECT_NAME = "bedrock-support-bot"

app = Flask(__name__)

# Global variables
bedrock_agent_id = None
bedrock_runtime = None

def initialize_aws():
    """Initialize AWS clients and find the agent"""
    global bedrock_agent_id, bedrock_runtime
    
    try:
        # Initialize AWS session
        session = boto3.Session(profile_name=PROFILE, region_name=REGION)
        bedrock_agent = session.client('bedrock-agent')
        bedrock_runtime = session.client('bedrock-agent-runtime')
        
        # Find the agent
        response = bedrock_agent.list_agents()
        for agent in response.get('agentSummaries', []):
            if PROJECT_NAME in agent['agentName']:
                bedrock_agent_id = agent['agentId']
                print(f"✅ Found Bedrock agent: {bedrock_agent_id}")
                return True
        
        print("❌ No Bedrock agent found")
        return False
        
    except Exception as e:
        print(f"❌ Failed to initialize AWS: {e}")
        return False

def call_bedrock_agent(message):
    """Call the Bedrock agent with a message"""
    try:
        session_id = f"web-{uuid.uuid4().hex[:8]}"
        
        response = bedrock_runtime.invoke_agent(
            agentId=bedrock_agent_id,
            agentAliasId='TSTALIASID',
            sessionId=session_id,
            inputText=message
        )
        
        # Extract completion from response
        completion = ""
        if 'completion' in response:
            for event in response['completion']:
                if 'chunk' in event:
                    chunk = event['chunk']
                    if 'bytes' in chunk:
                        completion += chunk['bytes'].decode('utf-8')
        
        # If no completion found, try to extract from raw response
        if not completion:
            # Sometimes the response format is different
            completion = str(response.get('completion', 'I received your message but had trouble generating a response.'))
        
        return completion.strip() if completion else "I'm here to help! Could you please rephrase your question?"
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'ResourceNotFoundException':
            return "The agent is not available right now. Please try again later."
        elif error_code == 'AccessDeniedException':
            return "I don't have permission to access the agent. Please check the configuration."
        else:
            return f"I encountered an error: {error_code}. Please try again."
    except Exception as e:
        return f"I'm having technical difficulties: {str(e)}"

@app.route('/')
def index():
    """Serve the main chat interface"""
    return send_from_directory('.', 'index.html')

@app.route('/chat', methods=['POST'])
def chat():
    """Handle chat messages"""
    try:
        data = request.get_json()
        
        if not data or 'message' not in data:
            return jsonify({'error': 'No message provided'}), 400
        
        user_message = data['message'].strip()
        
        if not user_message:
            return jsonify({'error': 'Empty message'}), 400
        
        if len(user_message) > 500:
            return jsonify({'error': 'Message too long (max 500 characters)'}), 400
        
        # Check if agent is available
        if not bedrock_agent_id:
            return jsonify({'error': 'Bedrock agent not available. Please check the server logs.'}), 503
        
        # Call the Bedrock agent
        response = call_bedrock_agent(user_message)
        
        return jsonify({
            'response': response,
            'timestamp': time.time()
        })
        
    except Exception as e:
        return jsonify({'error': f'Server error: {str(e)}'}), 500

@app.route('/status')
def status():
    """Check server and agent status"""
    return jsonify({
        'server': 'running',
        'agent_available': bedrock_agent_id is not None,
        'agent_id': bedrock_agent_id,
        'timestamp': time.time()
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    print("🚀 Starting AWS Bedrock Support Bot Web Interface")
    print("=" * 50)
    
    # Initialize AWS connection
    if initialize_aws():
        print(f"🌐 Starting web server on http://localhost:5000")
        print("📱 Open your browser and go to: http://localhost:5000")
        print("🛑 Press Ctrl+C to stop the server")
        print("")
        
        # Start Flask app
        app.run(
            host='0.0.0.0',
            port=5000,
            debug=True,
            use_reloader=False  # Disable reloader to avoid double initialization
        )
    else:
        print("❌ Failed to initialize. Please check:")
        print("   1. AWS credentials are configured")
        print("   2. Bedrock agent is deployed")
        print("   3. Agent name contains 'bedrock-support-bot'")
        exit(1)
