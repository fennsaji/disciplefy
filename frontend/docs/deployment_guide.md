# Deployment Guide

## 🚀 **Deployment Overview**

This guide covers deploying the Flutter web app to multiple platforms, including Vercel (primary), Supabase Storage, and GitHub Pages. It includes CSP configuration and automated deployment via GitHub Actions.

## 🎯 **Deployment Targets**

### **Production Deployment (Vercel)**
- **Platform**: Vercel
- **URL**: `https://disciplefy.vercel.app`
- **CDN**: Vercel Edge Network
- **Custom Domain**: `disciplefy.com` (optional)
- **SSL**: Automatic HTTPS with Let's Encrypt

### **Alternative Production (Supabase Storage)**
- **Platform**: Supabase Storage
- **URL**: `https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/`
- **Bucket**: `disciplefy`
- **CDN**: Supabase Edge Network

### **Staging Deployment (Vercel Preview)**
- **Platform**: Vercel Preview
- **URL**: `https://disciplefy-{branch}.vercel.app`
- **Trigger**: Pull requests and feature branches
- **Environment**: Preview environment with staging data

## 🔧 **Manual Deployment**

### **Option 1: Vercel Deployment (Recommended)**

#### **Step 1: Prerequisites**
```bash
# Install Vercel CLI
npm install -g vercel@latest

# Login to Vercel
vercel login

# Verify connection
vercel whoami
vercel projects list
```

#### **Step 2: Build for Production**
```bash
# Navigate to frontend directory
cd frontend

# Clean build
flutter clean
flutter pub get

# Build for production (Vercel)
flutter build web --release \
  --web-renderer canvaskit \
  --base-href "/" \
  --dart-define=APP_URL=https://disciplefy.vercel.app \
  --dart-define=FLUTTER_WEB_BUILD=true \
  --dart-define=SUPABASE_URL="https://wzdcwxvyjuxjgzpnukvm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key"
```

#### **Step 3: Deploy to Vercel**
```bash
# Deploy to Vercel
cd build/web
vercel --prod

# Or deploy with project name
vercel --prod --name disciplefy

# Check deployment status
vercel ls disciplefy
```

#### **Step 4: Test Deployment**
```bash
# Test the deployed app
curl -I "https://disciplefy.vercel.app"

# Open in browser
open "https://disciplefy.vercel.app"
```

### **Option 2: Supabase Storage Deployment**

#### **Step 1: Prerequisites**
```bash
# Install Supabase CLI
npm install -g supabase@1.123.4

# Login to Supabase
supabase login

# Verify connection
supabase projects list
```

#### **Step 2: Build for Production**
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

#### **Step 3: Deploy to Supabase Storage**
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

#### **Step 4: Test Deployment**
```bash
# Test the deployed app
curl -I "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/index.html"

# Open in browser
open "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/"
```

## 🎛️ **Vercel Configuration**

### **vercel.json Configuration**
Create a `vercel.json` file in your project root:

```json
{
  "version": 2,
  "name": "disciplefy",
  "builds": [
    {
      "src": "frontend/build/web/**",
      "use": "@vercel/static"
    }
  ],
  "routes": [
    {
      "handle": "filesystem"
    },
    {
      "src": "/(.*)",
      "dest": "/frontend/build/web/index.html"
    }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-XSS-Protection",
          "value": "1; mode=block"
        },
        {
          "key": "Referrer-Policy",
          "value": "strict-origin-when-cross-origin"
        },
        {
          "key": "Permissions-Policy",
          "value": "camera=(), microphone=(), geolocation=()"
        }
      ]
    },
    {
      "source": "/static/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ],
  "env": {
    "APP_URL": "https://disciplefy.vercel.app",
    "FLUTTER_WEB_BUILD": "true",
    "SUPABASE_URL": "https://wzdcwxvyjuxjgzpnukvm.supabase.co",
    "SUPABASE_ANON_KEY": "@supabase_anon_key"
  }
}
```

### **Environment Variables**
Configure in Vercel Dashboard → Project Settings → Environment Variables:

| Variable Name | Value | Environment |
|---------------|-------|-------------|
| `APP_URL` | `https://disciplefy.vercel.app` | Production |
| `FLUTTER_WEB_BUILD` | `true` | All |
| `SUPABASE_URL` | `https://wzdcwxvyjuxjgzpnukvm.supabase.co` | All |
| `SUPABASE_ANON_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` | All |

### **Custom Domain Setup**
```bash
# Add custom domain
vercel domains add disciplefy.com

# Configure domain
vercel domains inspect disciplefy.com

# Set domain for project
vercel alias set disciplefy.vercel.app disciplefy.com
```

## 🤖 **Automated Deployment (GitHub Actions)**

### **Workflow Configuration - Vercel**
The deployment is automated via `.github/workflows/vercel-deploy.yml`:

```yaml
name: Vercel Deployment

on:
  push:
    branches: [ main ]
    paths: [ 'frontend/**' ]
  pull_request:
    branches: [ main ]
    paths: [ 'frontend/**' ]
  workflow_dispatch:

jobs:
  deploy:
    name: Deploy to Vercel
    runs-on: ubuntu-latest
    environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'preview' }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.1'
          channel: 'stable'
          cache: true
      
      - name: Install Dependencies
        run: |
          cd frontend
          flutter pub get
      
      - name: Build Web App
        run: |
          cd frontend
          flutter build web --release \
            --web-renderer canvaskit \
            --base-href "/" \
            --dart-define=APP_URL=${{ github.ref == 'refs/heads/main' && 'https://disciplefy.vercel.app' || 'https://disciplefy-preview.vercel.app' }} \
            --dart-define=FLUTTER_WEB_BUILD=true \
            --dart-define=SUPABASE_URL="${{ secrets.SUPABASE_URL }}" \
            --dart-define=SUPABASE_ANON_KEY="${{ secrets.SUPABASE_ANON_KEY }}"
      
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: frontend/build/web
          production: ${{ github.ref == 'refs/heads/main' }}
          scope: ${{ secrets.VERCEL_ORG_ID }}
```

### **Alternative Workflow - Supabase Storage**
For Supabase Storage deployment, use `.github/workflows/supabase-deploy.yml`:

```yaml
name: Supabase Storage Deployment

on:
  push:
    branches: [ main ]
    paths: [ 'frontend/**' ]
  workflow_dispatch:

jobs:
  deploy:
    name: Deploy to Supabase Storage
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.1'
          channel: 'stable'
          cache: true
      
      - name: Build Web App
        run: |
          cd frontend
          flutter pub get
          flutter build web --release \
            --web-renderer canvaskit \
            --base-href "/" \
            --dart-define=FLUTTER_WEB_BUILD=true \
            --dart-define=SUPABASE_URL="${{ secrets.SUPABASE_URL }}" \
            --dart-define=SUPABASE_ANON_KEY="${{ secrets.SUPABASE_ANON_KEY }}"
      
      - name: Deploy to Supabase Storage
        run: |
          npm install -g supabase@1.123.4
          cd frontend/build/web
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

#### **For Vercel Deployment:**
| Secret Name | Description | How to Get |
|-------------|-------------|-----------|
| `VERCEL_TOKEN` | Vercel API token | Vercel Dashboard → Settings → Tokens |
| `VERCEL_ORG_ID` | Vercel organization ID | Vercel Dashboard → Settings → General |
| `VERCEL_PROJECT_ID` | Vercel project ID | Project Settings → General |
| `SUPABASE_URL` | Supabase project URL | `https://wzdcwxvyjuxjgzpnukvm.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | Supabase Dashboard → Settings → API |

#### **For Supabase Storage Deployment:**
| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SUPABASE_ACCESS_TOKEN` | Supabase CLI access token | `sbp_xxx...` |
| `SUPABASE_PROJECT_REF` | Supabase project reference | `wzdcwxvyjuxjgzpnukvm` |
| `SUPABASE_URL` | Supabase project URL | `https://wzdcwxvyjuxjgzpnukvm.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |

### **Triggering Deployment**

#### **Vercel Deployment:**
```bash
# Automatic deployment (on push to main)
git push origin main

# Preview deployment (on PR)
git checkout -b feature/new-feature
git push origin feature/new-feature
# Create PR → automatic preview deployment

# Manual deployment (via GitHub Actions)
# Go to Actions tab → Vercel Deployment → Run workflow
```

#### **Supabase Storage Deployment:**
```bash
# Automatic deployment (on push to main)
git push origin main

# Manual deployment (via GitHub Actions)
# Go to Actions tab → Supabase Storage Deployment → Run workflow
```

## 🔍 **Deployment Verification**

### **Automated Checks**

#### **Vercel Deployment Checks:**
```bash
# HTTP status check
response=$(curl -s -o /dev/null -w "%{http_code}" "https://disciplefy.vercel.app")

if [ "$response" = "200" ]; then
  echo "✅ Vercel deployment successful (HTTP $response)"
else
  echo "❌ Vercel deployment failed (HTTP $response)"
fi

# Check deployment status
vercel ls disciplefy
```

#### **Supabase Storage Deployment Checks:**
```bash
# HTTP status check
response=$(curl -s -o /dev/null -w "%{http_code}" "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/index.html")

if [ "$response" = "200" ]; then
  echo "✅ Supabase deployment successful (HTTP $response)"
else
  echo "❌ Supabase deployment failed (HTTP $response)"
fi
```

### **Manual Verification Steps**

#### **For Vercel Deployment:**
1. **Check HTTP Status**: Ensure `https://disciplefy.vercel.app` returns 200 OK
2. **Test CSP**: Verify no CSP violations in browser console
3. **Test Functionality**: Ensure all features work
4. **Check Performance**: Verify acceptable loading times
5. **Test Mobile**: Check responsive design
6. **Verify Environment**: Check that environment variables are correctly set

#### **For Supabase Storage Deployment:**
1. **Check HTTP Status**: Ensure Supabase storage URL returns 200 OK
2. **Test CSP**: Verify no CSP violations in browser console
3. **Test Functionality**: Ensure all features work
4. **Check Performance**: Verify acceptable loading times
5. **Test Mobile**: Check responsive design

### **Post-Deployment Checklist**
- [ ] App loads successfully at production URL
- [ ] No JavaScript errors in console
- [ ] No CSP violations
- [ ] Authentication works with Supabase
- [ ] API calls succeed
- [ ] All pages/routes work correctly
- [ ] Mobile responsive design
- [ ] Performance acceptable (< 3s load time)
- [ ] PWA installation works
- [ ] Service worker registers correctly

## 🛠️ **Deployment Troubleshooting**

### **Common Issues**

#### **Vercel Deployment Issues:**

##### **1. Vercel CLI Authentication Failed**
```bash
# Error: "Authentication failed"
# Solution: Login to Vercel
vercel login

# Or set token manually:
export VERCEL_TOKEN="your-vercel-token"
```

##### **2. Build Fails on Vercel**
```bash
# Error: Flutter build fails
# Solution: Check Flutter version and dependencies
flutter --version
flutter clean
flutter pub get
flutter doctor
flutter build web --verbose
```

##### **3. Environment Variables Not Set**
```bash
# Error: Environment variables undefined
# Solution: Check Vercel project settings
vercel env ls
vercel env add SUPABASE_URL
vercel env add SUPABASE_ANON_KEY
```

##### **4. Function Timeout**
```bash
# Error: Function execution timed out
# Solution: Check vercel.json configuration
# Add to vercel.json:
{
  "functions": {
    "frontend/build/web/index.html": {
      "maxDuration": 30
    }
  }
}
```

#### **Supabase Storage Issues:**

##### **1. Supabase CLI Authentication Failed**
```bash
# Error: "Authentication failed"
# Solution: Regenerate access token
supabase login
# Or set token manually:
export SUPABASE_ACCESS_TOKEN="your-new-token"
```

##### **2. Build Fails**
```bash
# Error: Flutter build fails
# Solution: Check dependencies and clean build
flutter clean
flutter pub get
flutter doctor
flutter build web --verbose
```

##### **3. CSP Violations After Deployment**
```bash
# Error: CSP blocks resources
# Solution: Check CSP in deployed index.html
curl -s "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/index.html" | grep -i "content-security-policy"
```

#### **Common Issues (Both Platforms):**

##### **1. Assets Not Loading**
```bash
# Error: Images, fonts, etc. not loading
# Solution: Check asset paths and base href
# Vercel:
curl -I "https://disciplefy.vercel.app/assets/AssetManifest.json"
# Supabase:
curl -I "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/assets/AssetManifest.json"
```

##### **2. API Connection Issues**
```bash
# Error: API calls fail
# Solution: Check CORS and environment variables
# Test API connectivity:
curl -I "https://wzdcwxvyjuxjgzpnukvm.supabase.co/functions/v1/env-test"
```

##### **3. PWA Installation Issues**
```bash
# Error: PWA doesn't install
# Solution: Check manifest.json and service worker
# Vercel:
curl -I "https://disciplefy.vercel.app/manifest.json"
# Supabase:
curl -I "https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/manifest.json"
```

### **Debug Commands**

#### **Vercel Debug Commands:**
```bash
# Check deployment status
vercel ls disciplefy

# Check deployment logs
vercel logs disciplefy

# Check environment variables
vercel env ls

# Test specific files
curl -I "https://disciplefy.vercel.app/flutter.js"
curl -I "https://disciplefy.vercel.app/manifest.json"

# Check headers
curl -I "https://disciplefy.vercel.app"

# Download deployed file for inspection
curl -s "https://disciplefy.vercel.app/index.html" > debug_index.html
```

#### **Supabase Debug Commands:**
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

### **Vercel Deployment Success:**
Your Vercel deployment is successful when:
- ✅ **GitHub Actions workflow** completes without errors
- ✅ **App loads** at `https://disciplefy.vercel.app`
- ✅ **No console errors** in browser
- ✅ **All features work** as expected
- ✅ **Performance is acceptable** (< 3s load time)
- ✅ **Mobile responsive** design works
- ✅ **PWA installation** works correctly
- ✅ **Environment variables** are set correctly
- ✅ **Custom domain** (if configured) works

### **Supabase Storage Deployment Success:**
Your Supabase deployment is successful when:
- ✅ **GitHub Actions workflow** completes without errors
- ✅ **App loads** at the Supabase Storage URL
- ✅ **No console errors** in browser
- ✅ **All features work** as expected
- ✅ **Performance is acceptable** (< 3s load time)
- ✅ **Mobile responsive** design works
- ✅ **CSP violations resolved**

## 📚 **Quick Reference**

### **Production Build Command:**
```bash
flutter build web --release \
  --base-href "/" \
  --dart-define=APP_URL=https://disciplefy.vercel.app \
  --dart-define=FLUTTER_WEB_BUILD=true \
  --dart-define=SUPABASE_URL="https://wzdcwxvyjuxjgzpnukvm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key"
```

### **Deployment URLs:**
- **Primary (Vercel)**: https://disciplefy.vercel.app
- **Alternative (Supabase)**: https://wzdcwxvyjuxjgzpnukvm.supabase.co/storage/v1/object/public/disciplefy/
- **Preview (Vercel)**: https://disciplefy-{branch}.vercel.app

### **Key Files:**
- `vercel.json` - Vercel configuration
- `frontend/build/web/` - Built Flutter web app
- `.github/workflows/vercel-deploy.yml` - Vercel deployment workflow
- `.github/workflows/supabase-deploy.yml` - Supabase deployment workflow

---

*This guide ensures reliable, automated deployment of your Flutter web app to Vercel (primary) or Supabase Storage with proper configuration and monitoring.*