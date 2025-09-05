#!/bin/bash

# KeepAnEye Vercel Deployment Script
# Run this script from the project root directory

echo "🚀 KeepAnEye Vercel Deployment"
echo "==============================="

# Check if we're in the right directory
if [ ! -f "backend/package.json" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Backend deployment
echo ""
echo "📦 Backend Deployment to Vercel"
echo "--------------------------------"

cd backend

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "❌ Vercel CLI not found. Installing..."
    npm install -g vercel
fi

# Check if logged into Vercel
if ! vercel whoami &> /dev/null; then
    echo "🔐 Please login to Vercel:"
    vercel login
fi

# Build the project
echo "🔨 Building project..."
npm run build

# Deploy to Vercel
echo "🚀 Deploying to Vercel..."
vercel --prod

# Set environment variables
echo "⚙️ Setting environment variables..."
vercel env add NODE_ENV production
vercel env add JWT_SECRET $(openssl rand -base64 32)
vercel env add JWT_EXPIRES_IN 24h
vercel env add BCRYPT_ROUNDS 12
vercel env add RATE_LIMIT_WINDOW_MS 900000
vercel env add RATE_LIMIT_MAX_REQUESTS 100

# Get the deployment URL
DEPLOYMENT_URL=$(vercel ls --json | jq -r '.projects[0].url' 2>/dev/null || echo "https://your-app.vercel.app")

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
echo "- Monitor logs: vercel logs"
echo ""
echo "🔗 Vercel Dashboard: https://vercel.com/dashboard"
