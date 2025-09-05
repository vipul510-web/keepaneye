#!/bin/bash

# KeepAnEye Production Deployment Script
# Run this script from the project root directory

echo "🚀 KeepAnEye Production Deployment"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "backend/package.json" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Backend deployment
echo ""
echo "📦 Choose your deployment platform:"
echo "1. Vercel (Recommended - Best for Node.js)"
echo "2. Heroku (Traditional hosting)"
echo "3. Exit"
echo ""
read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo ""
        echo "🚀 Deploying to Vercel..."
        ./deploy-vercel.sh
        ;;
    2)
        echo ""
        echo "🚀 Deploying to Heroku..."
        # Heroku deployment logic
        cd backend

        # Check if Heroku CLI is installed
        if ! command -v heroku &> /dev/null; then
            echo "❌ Heroku CLI not found. Please install it first:"
            echo "   brew install heroku/brew/heroku"
            exit 1
        fi

        # Check if logged into Heroku
        if ! heroku auth:whoami &> /dev/null; then
            echo "🔐 Please login to Heroku:"
            heroku login
        fi

        # Create Heroku app if it doesn't exist
        if ! heroku apps:info keepaneye-backend &> /dev/null; then
            echo "📱 Creating Heroku app..."
            heroku create keepaneye-backend
        else
            echo "✅ Heroku app already exists"
        fi

        # Add PostgreSQL if not already added
        if ! heroku addons:info heroku-postgresql &> /dev/null; then
            echo "🗄️ Adding PostgreSQL database..."
            heroku addons:create heroku-postgresql:mini
        else
            echo "✅ PostgreSQL already added"
        fi

        # Set environment variables
        echo "⚙️ Setting environment variables..."
        heroku config:set NODE_ENV=production
        heroku config:set JWT_SECRET=$(openssl rand -base64 32)
        heroku config:set JWT_EXPIRES_IN=24h
        heroku config:set BCRYPT_ROUNDS=12
        heroku config:set RATE_LIMIT_WINDOW_MS=900000
        heroku config:set RATE_LIMIT_MAX_REQUESTS=100

        # Build and deploy
        echo "🔨 Building and deploying..."
        npm run build
        git add .
        git commit -m "Production deployment $(date)"
        git push heroku main

        # Run migrations
        echo "🗄️ Running database migrations..."
        heroku run npm run migrate

        echo ""
        echo "✅ Backend deployed successfully!"
        echo "🌐 Your backend URL: https://keepaneye-backend.herokuapp.com"

        cd ..
        ;;
    3)
        echo "👋 Exiting..."
        exit 0
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "📱 Next Steps for iOS App:"
echo "1. Update the API base URL in your iOS app to your deployed backend URL"
echo "2. Archive and upload to App Store Connect"
echo "3. Submit for App Store review"
echo ""
echo "📋 Don't forget to:"
echo "- Test the production backend"
echo "- Update iOS app with new API URL"
echo "- Complete App Store Connect setup"
echo "- Monitor logs"
