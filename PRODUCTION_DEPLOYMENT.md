# KeepAnEye Production Deployment Guide

## 🚀 Backend Deployment

### Option 1: Vercel (Recommended)

Vercel is perfect for Node.js applications with automatic deployments, serverless functions, and excellent performance.

**Why Vercel?**
- ✅ **Automatic Deployments**: Deploy on every git push
- ✅ **Global CDN**: Fast loading worldwide
- ✅ **Serverless Functions**: Pay only for what you use
- ✅ **Built-in Analytics**: Monitor performance
- ✅ **Free Tier**: Generous free tier for startups
- ✅ **Easy Scaling**: Automatic scaling based on traffic
- ✅ **Zero Configuration**: Works out of the box
- ✅ **Database Integration**: Vercel Postgres included

#### 1. Install Vercel CLI
```bash
npm install -g vercel
```

#### 2. Login to Vercel
```bash
vercel login
```

#### 3. Deploy Backend
```bash
cd backend
vercel
```

#### 4. Set Environment Variables
```bash
vercel env add NODE_ENV production
vercel env add JWT_SECRET your-super-secure-jwt-secret-key-here
vercel env add JWT_EXPIRES_IN 24h
vercel env add BCRYPT_ROUNDS 12
vercel env add RATE_LIMIT_WINDOW_MS 900000
vercel env add RATE_LIMIT_MAX_REQUESTS 100
```

#### 5. Add Database

**Option A: Vercel Postgres (Recommended)**
```bash
# Add Vercel Postgres
vercel storage add postgres
```

**Option B: External PostgreSQL**
- **Railway**: https://railway.app (free tier available)
- **Supabase**: https://supabase.com (free tier available)
- **Neon**: https://neon.tech (free tier available)

For external databases, add the connection string:
```bash
vercel env add DATABASE_URL "postgresql://username:password@host:port/database"
```

#### 6. Run Database Migrations
```bash
# After setting up the database
vercel env pull .env.local
npm run migrate
```
```json
{
  "version": 2,
  "builds": [
    {
      "src": "dist/index.js",
      "use": "@vercel/node"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "dist/index.js"
    }
  ]
}
```

### Option 2: Heroku

1. **Install Heroku CLI**
   ```bash
   brew install heroku/brew/heroku
   ```

2. **Login to Heroku**
   ```bash
   heroku login
   ```

3. **Create Heroku App**
   ```bash
   cd backend
   heroku create keepaneye-backend
   ```

4. **Add PostgreSQL Database**
   ```bash
   heroku addons:create heroku-postgresql:mini
   ```

5. **Set Environment Variables**
   ```bash
   heroku config:set NODE_ENV=production
   heroku config:set JWT_SECRET=your-super-secure-jwt-secret-key-here
   heroku config:set JWT_EXPIRES_IN=24h
   heroku config:set BCRYPT_ROUNDS=12
   heroku config:set RATE_LIMIT_WINDOW_MS=900000
   heroku config:set RATE_LIMIT_MAX_REQUESTS=100
   ```

6. **Deploy**
   ```bash
   git add .
   git commit -m "Production deployment"
   git push heroku main
   ```

7. **Run Database Migrations**
   ```bash
   heroku run npm run migrate
   ```

### Option 2: Railway

1. **Connect GitHub Repository**
2. **Add PostgreSQL Service**
3. **Set Environment Variables**
4. **Deploy**

### Option 3: DigitalOcean App Platform

1. **Create App from GitHub**
2. **Add Database**
3. **Configure Environment**

## 📱 iOS App Deployment

### 1. Update API Base URL

Update the backend URL in your iOS app:

```swift
// In NetworkManager.swift or similar
let baseURL = "https://your-backend-domain.herokuapp.com"
```

### 2. App Store Connect Setup

1. **Create App Record**
   - Go to App Store Connect
   - Create new app
   - Fill in app information

2. **App Information**
   - **Name**: KeepAnEye
   - **Bundle ID**: com.yourcompany.keepaneye
   - **SKU**: keepaneye-ios
   - **Primary Language**: English

3. **App Review Information**
   - **Contact Information**: Your details
   - **Demo Account**: Provide test credentials
   - **Notes**: Explain app functionality

### 3. Build and Upload

1. **Archive App**
   ```bash
   # In Xcode
   Product → Archive
   ```

2. **Upload to App Store Connect**
   - Use Xcode Organizer
   - Or use `xcodebuild` command line

3. **Submit for Review**
   - Complete app metadata
   - Add screenshots
   - Submit for review

## 🔧 Production Checklist

### Backend
- [ ] Environment variables configured
- [ ] Database migrations run
- [ ] SSL certificate installed
- [ ] Rate limiting enabled
- [ ] CORS configured for production domain
- [ ] Error logging set up
- [ ] Health check endpoint working

### iOS App
- [ ] API base URL updated
- [ ] App icons added
- [ ] Launch screen configured
- [ ] Privacy policy implemented
- [ ] App Store metadata complete
- [ ] TestFlight testing done

### Security
- [ ] JWT secret is secure and unique
- [ ] Database credentials are secure
- [ ] API endpoints are protected
- [ ] Rate limiting is appropriate
- [ ] CORS is properly configured

## 📊 Monitoring & Analytics

### Backend Monitoring
- Set up logging (Winston or similar)
- Configure error tracking (Sentry)
- Set up uptime monitoring

### iOS Analytics
- Implement crash reporting
- Add usage analytics (Firebase Analytics)
- Set up push notifications (optional)

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow
```yaml
name: Deploy to Production
on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to Heroku
        uses: akhileshns/heroku-deploy@v3.12.12
        with:
          heroku_api_key: ${{ secrets.HEROKU_API_KEY }}
          heroku_app_name: "keepaneye-backend"
          heroku_email: ${{ secrets.HEROKU_EMAIL }}
```

## 🚨 Emergency Procedures

### Rollback Plan
1. **Backend**: Use Heroku rollback or database restore
2. **iOS**: Submit new version with fixes
3. **Database**: Restore from backup

### Contact Information
- **Backend Issues**: Check Heroku logs
- **iOS Issues**: Check App Store Connect
- **Database Issues**: Check PostgreSQL logs

## 📈 Post-Launch

1. **Monitor Performance**
   - Response times
   - Error rates
   - User engagement

2. **Gather Feedback**
   - App Store reviews
   - User analytics
   - Support requests

3. **Plan Updates**
   - Bug fixes
   - Feature additions
   - Performance improvements
