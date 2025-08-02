#!/bin/bash
set -e

echo "🏗️  Building Flutter web for production..."

# Load production environment variables
export SUPABASE_URL="$SUPABASE_URL"
export SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
export APP_URL="https://disciplefy.vercel.app"
export SITE_URL="https://disciplefy.vercel.app"
export GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID"
export APPLE_CLIENT_ID="com.disciplefy.bible_study"
export RAZORPAY_KEY_ID="rzp_live_your-production-key"
export FLUTTER_ENV="production"
export LOG_LEVEL="error"

# Clean previous build
flutter clean
flutter pub get

# Build with production configuration
flutter build web --release \
  --base-href "/" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_URL="$APP_URL" \
  --dart-define=SITE_URL="$SITE_URL" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=APPLE_CLIENT_ID="$APPLE_CLIENT_ID" \
  --dart-define=RAZORPAY_KEY_ID="$RAZORPAY_KEY_ID" \
  --dart-define=FLUTTER_ENV="$FLUTTER_ENV" \
  --dart-define=LOG_LEVEL="$LOG_LEVEL" \
  --dart-define=FLUTTER_WEB_BUILD=true \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --dart-define=FLUTTER_WEB_AUTO_DETECT=false \
  --dart-define=ADDITIONAL_REDIRECT_URLS="https://disciplefy.vercel.app/auth/callback"

echo "✅ Production build complete!"
echo "📦 Build output: build/web/"