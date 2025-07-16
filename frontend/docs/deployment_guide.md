# Deployment Guide

## 🚀 **Deployment Overview**

This guide covers deploying the Flutter web app to Supabase Storage, including CSP configuration and automated deployment via GitHub Actions.

## 🎯 **Deployment Targets**

### **Production Deployment**
- **Platform**: Supabase Storage
- **URL**: `https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/`
- **Bucket**: `disciplefy`
- **CDN**: Supabase Edge Network

### **Staging Deployment** (Optional)
- **Platform**: Supabase Storage
- **Bucket**: `disciplefy-staging`
- **URL**: `https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy-staging/`

## 🔧 **Manual Deployment**

### **Step 1: Prerequisites**
```bash
# Install Supabase CLI
npm install -g supabase@1.123.4

# Login to Supabase
supabase login

# Verify connection
supabase projects list
```

### **Step 2: Build for Production**
```bash
# Navigate to frontend directory
cd frontend

# Clean build
flutter clean
flutter pub get

# Build for production
flutter build web --release \
  --web-renderer canvaskit \
  --base-href "/" \
  --dart-define=FLUTTER_WEB_BUILD=true \
  --dart-define=SUPABASE_URL="https://wzdcwxvyjuxjgzpnukvm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key"

# Optimize CSP (optional)
if [ -f "scripts/optimize_csp.sh" ]; then
  chmod +x scripts/optimize_csp.sh
  ./scripts/optimize_csp.sh
fi
```

### **Step 3: Deploy to Supabase Storage**
```bash
# Deploy to production bucket
supabase storage cp build/web ss://disciplefy/ \
  --recursive \
  --cache-control "max-age=3600" \
  --project-ref wzdcwxvyjuxjgzpnukvm \
  --experimental

# Verify deployment
supabase storage ls ss://disciplefy/ \
  --project-ref wzdcwxvyjuxjgzpnukvm
```

### **Step 4: Test Deployment**
```bash
# Test the deployed app
curl -I "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/index.html"

# Open in browser
open "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/"
```

## 🤖 **Automated Deployment (GitHub Actions)**

### **Workflow Configuration**
The deployment is automated via `.github/workflows/web-deploy.yml`:

```yaml
name: Frontend Deployment - Web & Mobile

on:
  push:
    branches: [ main ]
    paths: [ 'frontend/**' ]
  workflow_dispatch:
    inputs:
      platform:
        description: 'Platform to build'
        required: true
        default: 'web'
        type: choice
        options: [ web, android, ios, all ]

jobs:
  build-web:
    name: Build Flutter Web
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.1'
          channel: 'stable'
          cache: true
      
      - name: Build Web App
        run: |
          cd frontend
          flutter pub get
          flutter build web --release --web-renderer canvaskit
          
          # CSP optimization
          if [ -f "scripts/optimize_csp.sh" ]; then
            chmod +x scripts/optimize_csp.sh
            ./scripts/optimize_csp.sh
          fi

  deploy-web:
    name: Deploy to Supabase Storage
    needs: build-web
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: flutter-web-build
          path: ./web-build
      
      - name: Deploy to Supabase Storage
        run: |
          npm install -g supabase@1.123.4
          cd web-build
          supabase storage cp . ss://disciplefy/ \
            --recursive \
            --cache-control "max-age=3600" \
            --project-ref "${{ secrets.SUPABASE_PROJECT_REF }}" \
            --experimental
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
```

### **Required GitHub Secrets**
Configure these in your repository settings:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SUPABASE_ACCESS_TOKEN` | Supabase CLI access token | `sbp_xxx...` |
| `SUPABASE_PROJECT_REF` | Supabase project reference | `wzdcwxvyjuxjgzpnukvm` |
| `SUPABASE_URL` | Supabase project URL | `https://wzdcwxvyjuxjgzpnukvm.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |

### **Triggering Deployment**
```bash
# Automatic deployment (on push to main)
git push origin main

# Manual deployment (via GitHub Actions)
# Go to Actions tab → Web Deploy → Run workflow
```

## 🔍 **Deployment Verification**

### **Automated Checks**
The deployment workflow includes automated verification:

```bash
# HTTP status check
response=$(curl -s -o /dev/null -w "%{http_code}" "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/index.html")

if [ "$response" = "200" ]; then
  echo "✅ Deployment successful (HTTP $response)"
else
  echo "❌ Deployment failed (HTTP $response)"
fi
```

### **Manual Verification Steps**
1. **Check HTTP Status**: Ensure app returns 200 OK
2. **Test CSP**: Verify no CSP violations in browser console
3. **Test Functionality**: Ensure all features work
4. **Check Performance**: Verify acceptable loading times
5. **Test Mobile**: Check responsive design

### **Post-Deployment Checklist**
- [ ] App loads successfully
- [ ] No JavaScript errors in console
- [ ] No CSP violations
- [ ] Authentication works
- [ ] API calls succeed
- [ ] All pages/routes work
- [ ] Mobile responsive
- [ ] Performance acceptable

## 🛠️ **Deployment Troubleshooting**

### **Common Issues**

#### **1. Supabase CLI Authentication Failed**
```bash
# Error: "Authentication failed"
# Solution: Regenerate access token
supabase login
# Or set token manually:
export SUPABASE_ACCESS_TOKEN="your-new-token"
```

#### **2. Build Fails**
```bash
# Error: Flutter build fails
# Solution: Check dependencies and clean build
flutter clean
flutter pub get
flutter doctor
flutter build web --verbose
```

#### **3. CSP Violations After Deployment**
```bash
# Error: CSP blocks resources
# Solution: Check CSP in deployed index.html
curl -s "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/index.html" | grep -i "content-security-policy"
```

#### **4. Assets Not Loading**
```bash
# Error: Images, fonts, etc. not loading
# Solution: Check asset paths and CSP
curl -I "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/assets/AssetManifest.json"
```

#### **5. API Connection Issues**
```bash
# Error: API calls fail
# Solution: Check connect-src in CSP and CORS
curl -s "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/index.html" | grep -o "connect-src[^;]*"
```

### **Debug Commands**
```bash
# Check deployed files
supabase storage ls ss://disciplefy/ --project-ref wzdcwxvyjuxjgzpnukvm

# Check file contents
supabase storage cp ss://disciplefy/index.html ./debug_index.html --project-ref wzdcwxvyjuxjgzpnukvm

# Test specific file
curl -I "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/flutter.js"

# Check CSP in deployed file
curl -s "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/index.html" | grep -A5 -B5 "Content-Security-Policy"
```

## 📊 **Performance Optimization**

### **Build Optimization**
```bash
# Enable source maps for debugging
flutter build web --source-maps

# Optimize for size
flutter build web --release --web-renderer canvaskit --dart2js-optimization O4

# Enable tree shaking
flutter build web --tree-shake-icons

# Split defer loading
flutter build web --split-debug-info=./debug_symbols/
```

### **Cache Configuration**
```bash
# Set appropriate cache headers
supabase storage cp build/web ss://disciplefy/ \
  --recursive \
  --cache-control "max-age=31536000" \  # 1 year for assets
  --project-ref wzdcwxvyjuxjgzpnukvm

# Different cache for HTML
supabase storage cp build/web/index.html ss://disciplefy/index.html \
  --cache-control "max-age=300" \  # 5 minutes for HTML
  --project-ref wzdcwxvyjuxjgzpnukvm
```

### **Compression**
```bash
# Pre-compress assets
cd build/web
find . -type f \( -name "*.js" -o -name "*.css" -o -name "*.html" \) -exec gzip -k {} \;

# Upload compressed versions
supabase storage cp . ss://disciplefy/ \
  --recursive \
  --content-encoding "gzip" \
  --project-ref wzdcwxvyjuxjgzpnukvm
```

## 🔄 **Rollback Procedures**

### **Quick Rollback**
```bash
# Get previous version from Git
git checkout HEAD~1 -- frontend/

# Rebuild and deploy
cd frontend
flutter build web --release
supabase storage cp build/web ss://disciplefy/ \
  --recursive \
  --cache-control "max-age=3600" \
  --project-ref wzdcwxvyjuxjgzpnukvm \
  --experimental

# Return to latest
git checkout main -- frontend/
```

### **Backup Strategy**
```bash
# Create backup before deployment
supabase storage cp ss://disciplefy ss://disciplefy-backup-$(date +%Y%m%d) \
  --recursive \
  --project-ref wzdcwxvyjuxjgzpnukvm

# Restore from backup
supabase storage cp ss://disciplefy-backup-20240715 ss://disciplefy \
  --recursive \
  --project-ref wzdcwxvyjuxjgzpnukvm
```

## 🎯 **Deployment Environments**

### **Production Environment**
```bash
# Production deployment
flutter build web --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SUPABASE_URL="https://wzdcwxvyjuxjgzpnukvm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="prod-key"

supabase storage cp build/web ss://disciplefy/ \
  --recursive \
  --project-ref wzdcwxvyjuxjgzpnukvm
```

### **Staging Environment**
```bash
# Staging deployment
flutter build web --release \
  --dart-define=ENVIRONMENT=staging \
  --dart-define=SUPABASE_URL="https://staging-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="staging-key"

supabase storage cp build/web ss://disciplefy-staging/ \
  --recursive \
  --project-ref staging-project-ref
```

## 📈 **Monitoring and Analytics**

### **Deployment Metrics**
- **Build Time**: Target < 5 minutes
- **Deploy Time**: Target < 2 minutes
- **Success Rate**: Target > 95%
- **Rollback Time**: Target < 1 minute

### **Performance Metrics**
- **First Contentful Paint**: Target < 2 seconds
- **Largest Contentful Paint**: Target < 3 seconds
- **Time to Interactive**: Target < 5 seconds
- **Bundle Size**: Target < 2MB

### **Health Checks**
```bash
# Automated health check
curl -f "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/index.html" > /dev/null && echo "✅ App is healthy" || echo "❌ App is down"

# Check API connectivity
curl -f "https://wzdcwxvyjuxjgzpnukvm.supabase.co/functions/v1/env-test" > /dev/null && echo "✅ API is healthy" || echo "❌ API is down"
```

## 🎉 **Success Indicators**

Your deployment is successful when:
- ✅ **GitHub Actions workflow** completes without errors
- ✅ **App loads** at the production URL
- ✅ **No console errors** in browser
- ✅ **All features work** as expected
- ✅ **Performance is acceptable** (< 3s load time)
- ✅ **Mobile responsive** design works
- ✅ **CSP violations resolved**

---

*This guide ensures reliable, automated deployment of your Flutter web app to Supabase Storage with proper CSP configuration.*

flutter build web --release \
  --base-href / --dart-define=APP_URL=https://disciplefy.vercel.app --dart-define=FLUTTER_WEB_BUILD=true \
          --dart-define=SUPABASE_URL="https://wzdcwxvyjuxjgzpnukvm.supabase.co" \
          --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6ZGN3eHZ5anV4amd6cG51a3ZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4MDY3MjMsImV4cCI6MjA2NzM4MjcyM30.FRwVStEigv5hh_-I8ct3QcY_GswCKWcEMCtkjXvq8FA"