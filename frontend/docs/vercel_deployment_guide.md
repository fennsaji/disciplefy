# Vercel Deployment Guide - Complete Process

## 📋 **Overview**

This guide walks you through deploying your Flutter web app to Vercel to resolve CSP (Content Security Policy) issues encountered with Supabase Storage.

## 🚨 **Why Deploy to Vercel?**

**Problem**: Supabase Storage serves files with restrictive CSP headers:
- `content-security-policy: default-src 'none'; sandbox`
- Blocks all JavaScript execution
- Cannot be overridden with meta tags

**Solution**: Vercel allows custom CSP headers and is designed for web applications.

## 🚀 **Step-by-Step Deployment Process**

### **Step 1: Create Vercel Configuration**

Create `vercel.json` in your `frontend/` directory:

```json
{
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Content-Security-Policy",
          "value": "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https: blob:; font-src 'self' data: https:; connect-src 'self' https://wzdcwxvyjuxjgzpnukvm.supabase.co wss://wzdcwxvyjuxjgzpnukvm.supabase.co https://api.openai.com https://api.anthropic.com; manifest-src 'self'; worker-src 'self' blob:; child-src 'self' blob:; frame-src 'self'; media-src 'self' data: blob:; object-src 'none'; base-uri 'self'; form-action 'self';"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "Referrer-Policy",
          "value": "strict-origin-when-cross-origin"
        }
      ]
    }
  ],
  "functions": {
    "build/web/**": {
      "maxDuration": 30
    }
  }
}
```

**What this does**:
- **Rewrites**: Routes all requests to `index.html` (SPA routing)
- **CSP Header**: Allows Flutter web to run without violations
- **Security Headers**: Additional security best practices
- **Functions**: Configures serverless function timeout

### **Step 2: Install Vercel CLI**

```bash
# Install Vercel CLI globally
npm install -g vercel

# Verify installation
vercel --version
```

### **Step 3: Login to Vercel**

```bash
# Start login process
vercel login

# Choose authentication method:
# ❯ Continue with GitHub (recommended)
#   Continue with GitLab
#   Continue with Bitbucket
#   Continue with Email
#   Continue with SAML Single Sign-On
```

**Select "Continue with GitHub"**:
1. Browser will open to GitHub OAuth page
2. Authorize Vercel to access your GitHub account
3. Return to terminal when complete

### **Step 4: Build Flutter Web App**

```bash
# Navigate to frontend directory
cd frontend

# Clean previous builds
flutter clean
flutter pub get

# Build for production
flutter build web --release \
  --dart-define=SUPABASE_URL="https://wzdcwxvyjuxjgzpnukvm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-supabase-anon-key"

# Verify build completed
ls -la build/web/
```

**Expected output**:
```
✓ Built build/web
```

### **Step 5: Deploy to Vercel**

```bash
# Navigate to build directory
cd build/web

# Deploy to production
vercel --prod --yes
```

**Deployment prompts**:
```
? Set up and deploy "~/path/to/build/web"? [Y/n] y
? Which scope do you want to deploy to? [Your Username]
? Link to existing project? [y/N] n
? What's your project's name? disciplefy-bible-study
? In which directory is your code located? ./
? Want to override the settings? [y/N] n
```

**Recommended answers**:
- **Set up and deploy**: `Y` (Yes)
- **Which scope**: Select your username/organization
- **Link to existing project**: `N` (No - create new project)
- **Project name**: `disciplefy-bible-study` (or your preferred name)
- **Code directory**: `./` (current directory)
- **Override settings**: `N` (No - use defaults)

### **Step 6: Verify Deployment**

After deployment, Vercel will provide:
- **Production URL**: `https://disciplefy-bible-study-xxx.vercel.app`
- **Dashboard URL**: `https://vercel.com/your-username/disciplefy-bible-study`

```bash
# Example success output:
✅  Production: https://disciplefy-bible-study-abc123.vercel.app [copied to clipboard] [3s]
📝  Deployed to production. Run `vercel --help` for more info.
```

## 🧪 **Testing Your Deployment**

### **Step 1: Open in Browser**
```bash
# Open the provided URL
open https://disciplefy-bible-study-xxx.vercel.app
```

### **Step 2: Check for CSP Errors**
1. **Open Developer Tools**: Press `F12` or right-click → Inspect
2. **Go to Console tab**
3. **Look for CSP violations**: Should see **no CSP-related errors**
4. **Check network tab**: All resources should load successfully

### **Step 3: Test App Functionality**
- [ ] App loads without errors
- [ ] Navigation works (routing)
- [ ] User authentication works
- [ ] API calls to Supabase succeed
- [ ] Daily verse loads
- [ ] Bible study generation works
- [ ] All styling renders correctly

### **Step 4: Verify CSP Headers**
```bash
# Check CSP headers are applied
curl -I https://disciplefy-bible-study-xxx.vercel.app

# Should see:
# content-security-policy: default-src 'self'; script-src 'self' 'unsafe-inline' ...
```

## 📊 **Performance Verification**

### **Loading Speed Test**
```bash
# Test loading time
curl -w "@curl-format.txt" -o /dev/null -s https://disciplefy-bible-study-xxx.vercel.app

# Expected results:
# - Time to first byte: < 500ms
# - Total time: < 2s
# - No errors
```

### **Bundle Size Analysis**
```bash
# Check main JavaScript bundle size
ls -lh build/web/main.dart.js

# Should be optimized and tree-shaken
# Typical size: 1-3MB for Flutter web
```

## 🔄 **Automatic Deployment with GitHub Actions**

### **Step 1: Get Vercel Tokens**

1. **Go to Vercel Dashboard**: https://vercel.com/dashboard
2. **Settings → Tokens**: https://vercel.com/account/tokens
3. **Create Token**: 
   - Name: `GitHub Actions`
   - Scope: Full Access
   - **Copy token** (starts with `vcel_`)

4. **Get Project IDs**:
   ```bash
   # Get project info
   vercel project ls
   
   # Get specific project details
   vercel project info disciplefy-bible-study
   ```

### **Step 2: Add GitHub Secrets**

Go to your GitHub repository → Settings → Secrets and variables → Actions:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `VERCEL_TOKEN` | Vercel authentication token | `vcel_xxxxxxx` |
| `VERCEL_ORG_ID` | Your Vercel organization ID | `team_xxxxxxx` |
| `VERCEL_PROJECT_ID` | Project ID from Vercel | `prj_xxxxxxx` |

### **Step 3: Create GitHub Actions Workflow**

Create `.github/workflows/deploy-vercel.yml`:

```yaml
name: Deploy to Vercel

on:
  push:
    branches: [ main ]
    paths:
      - 'frontend/**'
      - '.github/workflows/deploy-vercel.yml'
  workflow_dispatch:

concurrency:
  group: vercel-deploy-${{ github.ref }}
  cancel-in-progress: true

jobs:
  deploy:
    name: Deploy to Vercel
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.1'
          channel: 'stable'
          cache: true
          
      - name: Cache pub dependencies
        uses: actions/cache@v4
        with:
          path: |
            ~/.pub-cache
            frontend/.dart_tool
          key: ${{ runner.os }}-pub-${{ hashFiles('frontend/pubspec.lock') }}
          restore-keys: |
            ${{ runner.os }}-pub-
            
      - name: Install dependencies
        working-directory: ./frontend
        run: flutter pub get
        
      - name: Build Flutter Web
        working-directory: ./frontend
        run: |
          flutter build web --release \
            --dart-define=SUPABASE_URL="${{ secrets.SUPABASE_URL }}" \
            --dart-define=SUPABASE_ANON_KEY="${{ secrets.SUPABASE_ANON_KEY }}" \
            --dart-define=ENVIRONMENT=production
            
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: frontend/build/web
          vercel-args: '--prod'
          
      - name: Verify deployment
        run: |
          echo "🌍 App deployed to: https://disciplefy-bible-study.vercel.app"
          
          # Test deployment
          response=$(curl -s -o /dev/null -w "%{http_code}" "https://disciplefy-bible-study.vercel.app")
          
          if [ "$response" = "200" ]; then
            echo "✅ Deployment verification successful"
          else
            echo "❌ Deployment verification failed (HTTP $response)"
            exit 1
          fi
```

### **Step 4: Test Automatic Deployment**

```bash
# Push changes to trigger deployment
git add .
git commit -m "Setup Vercel deployment"
git push origin main

# Monitor deployment in GitHub Actions tab
# Should see successful deployment
```

## 🛠️ **Managing Your Vercel Project**

### **Vercel Dashboard**
- **Project URL**: `https://vercel.com/your-username/disciplefy-bible-study`
- **Deployments**: View all deployments and logs
- **Settings**: Configure custom domains, environment variables
- **Analytics**: Monitor performance and usage

### **Custom Domain Setup** (Optional)
```bash
# Add custom domain
vercel domains add your-domain.com

# Configure DNS records as instructed by Vercel
# Usually involves adding CNAME record
```

### **Environment Variables**
```bash
# Add environment variables via CLI
vercel env add SUPABASE_URL
vercel env add SUPABASE_ANON_KEY

# Or use Vercel dashboard:
# Project Settings → Environment Variables
```

## 🔍 **Troubleshooting**

### **Common Issues and Solutions**

#### **1. Build Fails**
```bash
# Error: Flutter build fails
# Solution: Check dependencies
flutter clean
flutter pub get
flutter doctor
flutter build web --verbose
```

#### **2. Deployment Fails**
```bash
# Error: Vercel deployment fails
# Solution: Check authentication
vercel whoami
vercel login

# Check project settings
vercel project ls
```

#### **3. CSP Violations Still Occur**
```bash
# Error: CSP violations in deployed app
# Solution: Check vercel.json is in build directory
cp frontend/vercel.json frontend/build/web/
vercel --prod --yes
```

#### **4. App Doesn't Load**
```bash
# Error: App shows blank page
# Solution: Check Flutter build output
ls -la frontend/build/web/
grep -i "error" frontend/build/web/main.dart.js
```

#### **5. API Calls Fail**
```bash
# Error: Supabase API calls fail
# Solution: Check CORS and connect-src in CSP
curl -I https://your-app.vercel.app
# Verify connect-src includes your Supabase URL
```

### **Debug Commands**
```bash
# Check deployment logs
vercel logs https://your-app.vercel.app

# Check build output
flutter build web --verbose

# Test locally before deployment
cd frontend/build/web
python3 -m http.server 8000
open http://localhost:8000
```

## 📈 **Performance Optimization**

### **Build Optimization**
```bash
# Optimize build for production
flutter build web --release \
  --tree-shake-icons \
  --dart2js-optimization O4 \
  --source-maps

# Check bundle size
ls -lh build/web/main.dart.js
```

### **Vercel Configuration**
```json
{
  "functions": {
    "build/web/**": {
      "maxDuration": 30
    }
  },
  "regions": ["iad1"],
  "framework": null
}
```

## 🎯 **Success Checklist**

After completing this guide, you should have:

### **✅ Deployment Success**
- [ ] Vercel project created and deployed
- [ ] App accessible at Vercel URL
- [ ] No CSP violations in browser console
- [ ] All Flutter features working
- [ ] API calls to Supabase successful

### **✅ Security & Performance**
- [ ] HTTPS enabled automatically
- [ ] CSP headers properly configured
- [ ] Security headers applied
- [ ] Fast loading times (< 3s)
- [ ] CDN distribution active

### **✅ Development Workflow**
- [ ] GitHub Actions deployment working
- [ ] Environment variables configured
- [ ] Monitoring and logging set up
- [ ] Custom domain configured (optional)

## 🎉 **Conclusion**

Your Flutter web app is now successfully deployed to Vercel with:
- ✅ **CSP issues resolved** completely
- ✅ **Production-ready hosting** with global CDN
- ✅ **Automatic HTTPS** and security headers
- ✅ **Automated deployment** via GitHub Actions
- ✅ **Better performance** than Supabase Storage

The app should now load without any CSP violations and provide a smooth user experience! 🚀

## 📞 **Support & Resources**

- **Vercel Documentation**: https://vercel.com/docs
- **Flutter Web Guide**: https://flutter.dev/web
- **CSP Reference**: https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
- **Troubleshooting**: See troubleshooting section above

---

*This guide provides a complete solution for deploying Flutter web apps with proper CSP configuration on Vercel.*