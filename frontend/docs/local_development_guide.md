# Local Development Guide

## 🏠 **Local Development Setup**

This guide covers how to set up and test the Flutter web app locally, including CSP configuration testing.

## 🚀 **Quick Start**

### **1. Standard Flutter Development**
```bash
# Navigate to frontend directory
cd frontend

# Install dependencies
flutter pub get

# Run in development mode
flutter run -d web-server --web-port 3000

# Open in browser
open http://localhost:3000
```

### **2. Production Build Testing**
```bash
# Build for production
flutter build web --release --web-renderer canvaskit

# Test production build locally
python3 -m http.server 8000 -d build/web

# Open production build
open http://localhost:8000
```

## 🔧 **CSP Testing Workflow**

### **Step 1: Basic CSP Test**
```bash
# Build the app
flutter build web --release

# Check CSP is present in built file
grep -i "content-security-policy" build/web/index.html

# Start local server
python3 -m http.server 8000 -d build/web

# Test in browser
open http://localhost:8000
```

### **Step 2: Verify CSP Resolution**
1. Open **Browser Developer Tools** (F12)
2. Go to **Console** tab
3. Look for CSP-related errors
4. Should see **no CSP violations**

### **Step 3: Test CSP Optimization (Optional)**
```bash
# Build first
flutter build web --release

# Run CSP optimization script
chmod +x scripts/optimize_csp.sh
./scripts/optimize_csp.sh

# Test optimized build
python3 -m http.server 8001 -d build/web
open http://localhost:8001
```

## 🧪 **Advanced Testing**

### **Test CSP Violations**
Run this in your browser console to test CSP:

```javascript
// Check current CSP
const csp = document.querySelector('meta[http-equiv="Content-Security-Policy"]');
console.log('Current CSP:', csp ? csp.content : 'No CSP found');

// Test inline style (should work with our CSP)
const testStyle = document.createElement('style');
testStyle.textContent = 'body { border: 2px solid red; }';
document.head.appendChild(testStyle);
console.log('✅ Inline style test completed');

// Monitor CSP violations
document.addEventListener('securitypolicyviolation', (e) => {
    console.error('🚨 CSP Violation:', {
        violatedDirective: e.violatedDirective,
        blockedURI: e.blockedURI,
        originalPolicy: e.originalPolicy
    });
});

// Test external resource loading
const img = document.createElement('img');
img.src = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
document.body.appendChild(img);
console.log('✅ Data URL image test completed');
```

### **Simulate Supabase Storage Environment**
```bash
# Create test environment
mkdir -p local_supabase_test/disciplefy

# Copy built files
cp -r build/web/* local_supabase_test/disciplefy/

# Serve from simulated environment
cd local_supabase_test
python3 -m http.server 8080

# Test at: http://localhost:8080/disciplefy/
open http://localhost:8080/disciplefy/
```

## 🛠️ **Development Tools**

### **Useful Commands**
```bash
# Clean build (when things go wrong)
flutter clean && flutter pub get

# Check Flutter web support
flutter doctor

# Build with verbose output
flutter build web --verbose

# Analyze code
flutter analyze

# Run tests
flutter test

# Format code
dart format .
```

### **Local Server Alternatives**
```bash
# Python 3 (recommended)
python3 -m http.server 8000 -d build/web

# Python 2 (if needed)
python -m SimpleHTTPServer 8000

# Node.js (if you have it)
npx http-server build/web -p 8000

# PHP (if available)
php -S localhost:8000 -t build/web
```

## 🔍 **Debugging Common Issues**

### **1. CSP Violations**
**Symptoms**: Console errors about blocked resources

**Debug Steps**:
```bash
# Check CSP in built file
grep -A5 -B5 "Content-Security-Policy" build/web/index.html

# Pretty print CSP
grep "Content-Security-Policy" build/web/index.html | sed 's/;/;\n/g'
```

**Solutions**:
- Hard refresh browser (Ctrl+F5)
- Check CSP syntax in `web/index.html`
- Verify meta tag is copied to `build/web/index.html`

### **2. Flutter Build Issues**
**Symptoms**: Build fails or app doesn't load

**Debug Steps**:
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build web --verbose

# Check for web-specific issues
flutter build web --release --source-maps
```

**Solutions**:
- Update Flutter: `flutter upgrade`
- Check pubspec.yaml for web-incompatible packages
- Verify all dependencies support web platform

### **3. API Connection Issues**
**Symptoms**: API calls fail locally but work in dev mode

**Debug Steps**:
```bash
# Check network tab in browser dev tools
# Verify connect-src includes your API domains
grep -o "connect-src[^;]*" build/web/index.html
```

**Solutions**:
- Add missing domains to `connect-src` in CSP
- Check CORS configuration on API server
- Verify API keys are correctly configured

### **4. Asset Loading Issues**
**Symptoms**: Images, fonts, or other assets don't load

**Debug Steps**:
```bash
# Check build directory structure
ls -la build/web/
ls -la build/web/assets/

# Check CSP allows required sources
grep -o "img-src[^;]*\|font-src[^;]*" build/web/index.html
```

**Solutions**:
- Verify assets are in `build/web/assets/`
- Check CSP allows `data:` URLs for base64 assets
- Ensure correct paths in Flutter code

## 📋 **Pre-Deployment Checklist**

### **✅ Before Deploying:**
- [ ] Flutter build completes without errors
- [ ] Local production build works correctly
- [ ] No CSP violations in browser console
- [ ] All app features function properly
- [ ] API calls succeed
- [ ] Images and fonts load correctly
- [ ] App is responsive on mobile
- [ ] Performance is acceptable

### **✅ Testing Checklist:**
- [ ] Home page loads
- [ ] Navigation works
- [ ] User authentication works
- [ ] Bible study generation works
- [ ] Daily verse displays
- [ ] Offline functionality (if implemented)
- [ ] All forms submit correctly

## 🎯 **Daily Development Workflow**

### **Morning Setup**
```bash
# Pull latest changes
git pull origin main

# Install any new dependencies
flutter pub get

# Start development server
flutter run -d web-server --web-port 3000
```

### **Testing Changes**
```bash
# Test in development mode first
# Make changes and hot reload

# Test production build before committing
flutter build web --release
python3 -m http.server 8000 -d build/web &
open http://localhost:8000

# Run tests
flutter test

# Clean up
pkill -f "python.*http.server"
```

### **Pre-commit Checks**
```bash
# Format code
dart format .

# Analyze code
flutter analyze

# Run tests
flutter test

# Build successfully
flutter build web --release
```

## 🚀 **Performance Testing**

### **Build Size Analysis**
```bash
# Check build size
du -sh build/web/
du -sh build/web/assets/

# Check individual files
ls -lah build/web/

# Analyze large files
find build/web -type f -size +1M -exec ls -lh {} \;
```

### **Loading Performance**
```bash
# Test with slow network
# Chrome DevTools → Network → Throttling → Slow 3G

# Check for unnecessary assets
# DevTools → Network → All → Sort by Size

# Verify gzip compression works
curl -H "Accept-Encoding: gzip" -v http://localhost:8000/main.dart.js
```

## 🔧 **Environment Configuration**

### **Development Environment Variables**
```bash
# Set development environment
export FLUTTER_ENV=development

# Enable debug logging
export LOG_LEVEL=debug

# Use development API endpoints
export API_BASE_URL=http://localhost:8080
```

### **Local Configuration File**
Create `.env.local` in frontend directory:
```bash
# Frontend environment variables
FLUTTER_ENV=development
API_BASE_URL=http://localhost:8080
ENABLE_DEBUG_LOGGING=true
```

## 📊 **Monitoring and Debugging**

### **Console Logging**
```dart
// Add to main.dart for debugging
import 'dart:developer' as developer;

void main() {
  developer.log('App starting in ${kDebugMode ? 'debug' : 'release'} mode');
  runApp(MyApp());
}
```

### **Network Monitoring**
```javascript
// Add to index.html for network debugging
window.addEventListener('load', () => {
  console.log('✅ App loaded successfully');
  console.log('🌐 Current URL:', window.location.href);
  console.log('📱 User Agent:', navigator.userAgent);
});
```

## 🎉 **Success Indicators**

Your local development setup is working correctly when:
- ✅ **Development server starts** without errors
- ✅ **Hot reload works** for quick development
- ✅ **Production build completes** successfully
- ✅ **No CSP violations** in browser console
- ✅ **All features work** in both dev and prod modes
- ✅ **Performance is acceptable** for your use case

---

*This guide ensures smooth local development and testing before deploying to production.*