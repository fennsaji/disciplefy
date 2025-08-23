#!/bin/bash
set -e

echo "🏗️  Building Flutter web for production..."

# Load production environment variables
export SUPABASE_URL="$SUPABASE_URL"
export SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
export APP_URL="https://www.disciplefy.in"
export GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID"
export FLUTTER_ENV="production"

# Clean previous build
flutter clean
flutter pub get

# Build with production configuration
flutter build web --release \
  --base-href "/" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_URL="$APP_URL" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=FLUTTER_ENV="$FLUTTER_ENV" \
  --dart-define=FLUTTER_WEB_BUILD=true \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --dart-define=FLUTTER_WEB_AUTO_DETECT=false

echo "✅ Production build complete!"
echo "📦 Build output: build/web/"