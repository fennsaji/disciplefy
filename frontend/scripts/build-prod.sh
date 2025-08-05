#!/bin/bash
set -e

echo "🏗️  Building Flutter web for production..."

# Load production environment variables
export SUPABASE_URL="https://wzdcwxvyjuxjgzpnukvm.supabase.co"
export SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6ZGN3eHZ5anV4amd6cG51a3ZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4MDY3MjMsImV4cCI6MjA2NzM4MjcyM30.FRwVStEigv5hh_-I8ct3QcY_GswCKWcEMCtkjXvq8FA"
export APP_URL="https://disciplefy.vercel.app"
export GOOGLE_CLIENT_ID="587108000155-af542dhgo9rmp5hvsm1vepgqsgil438d.apps.googleusercontent.com"
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