@echo off
echo 🚀 Starting AWS Bedrock Support Bot Web UI
echo ==========================================

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python is not installed or not in PATH
    echo Please install Python 3.9+ and try again
    pause
    exit /b 1
)

REM Install requirements
echo 📦 Installing Python dependencies...
pip install -r requirements.txt

REM Check if AWS CLI is configured
aws sts get-caller-identity --profile bedrock-user >nul 2>&1
if errorlevel 1 (
    echo ❌ AWS CLI not configured with bedrock-user profile
    echo Please run: aws configure --profile bedrock-user
    pause
    exit /b 1
)

echo ✅ Dependencies installed
echo 🌐 Starting web server...
echo.
echo 📱 Open your browser and go to: http://localhost:5000
echo 🛑 Press Ctrl+C to stop the server
echo.

REM Start the Flask app
python app.py

pause
