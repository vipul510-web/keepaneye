#!/bin/bash

# KeepAnEye Railway Deployment Script
# Run this script from the project root directory

echo "🚀 KeepAnEye Railway Deployment"
echo "==============================="

# Check if we're in the right directory
if [ ! -f "backend/package.json" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Backend deployment
echo ""
echo "📦 Backend Deployment to Railway"
echo "--------------------------------"

cd backend

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found. Installing..."
    npm install -g @railway/cli
fi

# Check if logged into Railway
if ! railway whoami &> /dev/null; then
    echo "🔐 Please login to Railway:"
    railway login
fi

# Build the project
echo "🔨 Building project..."
npm run build

# Deploy to Railway
echo "🚀 Deploying to Railway..."
railway up

# Get the deployment URL
DEPLOYMENT_URL=$(railway status --json | jq -r '.service.domain' 2>/dev/null || echo "https://your-app.railway.app")

echo ""
echo "✅ Backend deployed successfully!"
echo "🌐 Your backend URL: $DEPLOYMENT_URL"

cd ..

echo ""
echo "📱 Next Steps for iOS App:"
echo "1. Update the API base URL in your iOS app to:"
echo "   $DEPLOYMENT_URL"
echo "2. Archive and upload to App Store Connect"
echo "3. Submit for App Store review"
echo ""
echo "📋 Don't forget to:"
echo "- Test the production backend"
echo "- Update iOS app with new API URL"
echo "- Complete App Store Connect setup"
echo "- Monitor logs: railway logs"
echo ""
echo "🔗 Railway Dashboard: https://railway.app/dashboard"
