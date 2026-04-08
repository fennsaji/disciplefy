#!/bin/bash
set -e

echo "🏗️  Building Flutter web for production..."

# Load production environment variables from gitignored .env.production
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env.production"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Error: $ENV_FILE not found. Copy .env.example to .env.production and fill in values."
  exit 1
fi

set -a
# shellcheck source=../.env.production
source "$ENV_FILE"
set +a

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