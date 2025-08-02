# Vercel Deployment Guide

This document provides comprehensive instructions for deploying the Disciplefy Flutter web application to Vercel.

## 📋 Prerequisites

- Flutter SDK installed and configured
- Vercel CLI installed (`npm i -g vercel`)
- Project already linked to Vercel (Project ID: `prj_iCEFRzL9TJUuZUq5p5xhueiufiop`)

## 🚀 Quick Deployment

### Option 1: Command Line Deployment
```bash
cd frontend
flutter build web --release
vercel --prod
```

### Option 2: Using Deploy Script
```bash
cd frontend
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

## ⚙️ Configuration Details

### Vercel Configuration (`vercel.json`)
The project includes a pre-configured `vercel.json` with:

- **SPA Routing**: All routes redirect to `index.html` for proper Flutter web routing
- **Security Headers**: 
  - `X-Frame-Options: DENY`
  - `X-Content-Type-Options: nosniff`
  - `Referrer-Policy: strict-origin-when-cross-origin`
- **Function Timeout**: 30 seconds for build/web files

### Build Settings
- **Build Command**: `flutter build web --release`
- **Output Directory**: `build/web`
- **Install Command**: `flutter pub get`
- **Root Directory**: `frontend`

## 🌍 Environment Variables

### Required Environment Variables
Set these in Vercel dashboard or via CLI:

```bash
# Optimize Flutter web rendering
vercel env add FLUTTER_WEB_USE_SKIA true
vercel env add FLUTTER_WEB_AUTO_DETECT false

# Supabase configuration (if needed)
vercel env add SUPABASE_URL your_supabase_url
vercel env add SUPABASE_ANON_KEY your_supabase_anon_key
```

### Setting Environment Variables via CLI
```bash
# Add environment variable
vercel env add VARIABLE_NAME variable_value

# List environment variables
vercel env ls

# Remove environment variable
vercel env rm VARIABLE_NAME
```

## 🔄 Automatic Deployments

### GitHub Integration
1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to Settings → Git
4. Connect your GitHub repository
5. Set root directory to `frontend`
6. Enable auto-deploy on `main` branch

### Branch-based Deployments
- **Production**: Deploys from `main` branch
- **Preview**: Deploys from feature branches automatically
- **Development**: Manual deployments for testing

## 📝 Deployment Scripts

### Create Deploy Script
Create `frontend/scripts/deploy.sh`:

```bash
#!/bin/bash
set -e

echo "🏗️  Building Flutter web..."
flutter clean
flutter pub get
flutter build web --release

echo "📦 Optimizing build..."
# Remove source maps for production
find build/web -name "*.map" -delete

echo "🚀 Deploying to Vercel..."
vercel --prod

echo "✅ Deployment complete!"
echo "🌐 Your app is live at: https://disciplefy-bible-study.vercel.app"
```

Make it executable:
```bash
chmod +x scripts/deploy.sh
```

### Preview Deployment Script
Create `frontend/scripts/deploy-preview.sh`:

```bash
#!/bin/bash
set -e

echo "🏗️  Building Flutter web for preview..."
flutter build web --release

echo "🚀 Deploying preview to Vercel..."
vercel

echo "✅ Preview deployment complete!"
```

## 🌐 Custom Domain Setup

### Add Custom Domain
```bash
# Add your custom domain
vercel domains add yourdomain.com
vercel domains add www.yourdomain.com

# Verify domain
vercel domains verify yourdomain.com
```

### DNS Configuration
Point your domain to Vercel:
- **A Record**: `76.76.19.61`
- **CNAME Record**: `cname.vercel-dns.com`

## 🔍 Troubleshooting

### Common Issues

#### Build Failures
```bash
# Clear Flutter cache
flutter clean
flutter pub get

# Rebuild
flutter build web --release
```

#### Routing Issues
Ensure `vercel.json` includes the SPA rewrite rule:
```json
{
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```

#### Performance Issues
- Enable Skia renderer: `FLUTTER_WEB_USE_SKIA=true`
- Optimize images in `assets/` folder
- Use `flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true`

#### Environment Variable Issues
```bash
# Check current environment variables
vercel env ls

# Pull environment variables locally
vercel env pull .env.local
```

## 📊 Monitoring & Analytics

### Vercel Analytics
Enable analytics in Vercel dashboard:
1. Go to Project Settings
2. Navigate to Analytics
3. Enable Web Analytics
4. Add analytics script to `web/index.html` if needed

### Performance Monitoring
- Use Vercel's built-in performance monitoring
- Monitor Core Web Vitals
- Set up alerts for deployment failures

## 🔐 Security Considerations

### Headers Configuration
Current security headers in `vercel.json`:
- Prevents iframe embedding (`X-Frame-Options: DENY`)
- Prevents MIME type sniffing (`X-Content-Type-Options: nosniff`)
- Controls referrer information (`Referrer-Policy: strict-origin-when-cross-origin`)

### Additional Security
Consider adding:
```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Content-Security-Policy",
          "value": "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'"
        }
      ]
    }
  ]
}
```

## 📱 Mobile PWA Considerations

### PWA Configuration
The app includes PWA configuration in `web/manifest.json`:
- Ensure icons are optimized for all device sizes
- Test PWA installation on mobile devices
- Verify offline functionality if implemented

## 🚀 Deployment Checklist

Before deploying to production:

- [ ] Run `flutter analyze` and fix all issues
- [ ] Run `flutter test` and ensure all tests pass
- [ ] Test the app locally with `flutter run -d chrome --release`
- [ ] Verify all environment variables are set
- [ ] Check that `vercel.json` configuration is correct
- [ ] Test routing in production build
- [ ] Verify API endpoints are accessible
- [ ] Test on multiple browsers and devices
- [ ] Check performance metrics
- [ ] Verify security headers are working

## 📞 Support

### Useful Commands
```bash
# Check deployment status
vercel ls

# View deployment logs
vercel logs [deployment-url]

# Rollback to previous deployment
vercel rollback [deployment-url]

# Get project info
vercel project

# Link to different project
vercel link
```

### Resources
- [Vercel Documentation](https://vercel.com/docs)
- [Flutter Web Deployment](https://docs.flutter.dev/platform-integration/web/building)
- [Project Dashboard](https://vercel.com/dashboard)

---

**Last Updated**: July 31, 2025  
**Project ID**: `prj_iCEFRzL9TJUuZUq5p5xhueiufiop`  
**Live URL**: `https://disciplefy-bible-study.vercel.app`