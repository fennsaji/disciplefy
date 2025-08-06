#!/bin/bash

# Flutter Web Local Development Script with Hot Reload
# This script loads environment variables from specified env file and runs the Flutter app
# Flutter provides hot reload out of the box - no additional file watching needed!
# Usage: ./run-web-local.sh [env-file]
# Default: ./run-web-local.sh (uses .env.local)
# Examples: ./run-web-local.sh .env.dev

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default to .env.local if no parameter provided
ENV_FILE="${1:-.env.local}"

echo -e "${BLUE}🚀 Starting Flutter Web Local Development...${NC}"
echo -e "${BLUE}📄 Using environment file: ${ENV_FILE}${NC}"

# Check if specified env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file '$ENV_FILE' not found!${NC}"
    echo "Available environment files:"
    ls -la .env* 2>/dev/null || echo "No .env* files found"
    echo ""
    echo "Usage: $0 [env-file]"
    echo "Examples:"
    echo "  $0                 # Uses .env.local (default)"
    echo "  $0 .env.dev        # Uses .env.dev"
    echo "  $0 .env.production # Uses .env.production"
    exit 1
fi

# Load environment variables from specified file
echo -e "${GREEN}✅ Loading environment from: ${ENV_FILE}${NC}"
source "$ENV_FILE"

# Check if Supabase is accessible
echo -e "${BLUE}🔗 Testing Supabase connection: ${SUPABASE_URL}${NC}"
if ! curl -s "${SUPABASE_URL}/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ Supabase instance is not accessible!${NC}"
    echo "Please check:"
    echo "  • If using local Supabase: cd ../backend && supabase start"
    echo "  • If using remote Supabase: verify SUPABASE_URL in ${ENV_FILE}"
    echo "  • Current SUPABASE_URL: ${SUPABASE_URL}"
    exit 1
fi

echo -e "${GREEN}✅ Supabase instance is accessible${NC}"

# Get Flutter dependencies
echo -e "${BLUE}📦 Installing Flutter dependencies...${NC}"
flutter pub get

# Display development info
echo -e "${GREEN}🎉 Starting Flutter with hot reload enabled!${NC}"
echo -e "${BLUE}📍 App URL: http://localhost:59641${NC}"
echo -e "${BLUE}🔥 Hot reload: ${GREEN}ENABLED (built-in)${NC}"
echo -e ""
echo -e "${YELLOW}💬 Flutter Commands (once running):${NC}"
echo -e "  ${GREEN}r${NC} - Hot reload (apply changes instantly)"
echo -e "  ${GREEN}R${NC} - Hot restart (restart the app completely)"
echo -e "  ${GREEN}q${NC} - Quit development server"
echo -e "  ${GREEN}h${NC} - Show help"
echo -e "  ${GREEN}c${NC} - Clear console"
echo -e "  ${GREEN}o${NC} - Open app in browser"
echo -e ""
echo -e "${BLUE}📝 Flutter watches these automatically:${NC}"
echo -e "  • lib/ directory (all Dart source files)"
echo -e "  • pubspec.yaml (dependencies)"
echo -e "  • assets/ directory (images, fonts, etc.)"
echo -e ""
echo -e "${YELLOW}💡 Just save your files - Flutter will hot reload automatically!${NC}"
echo -e ""

# Run Flutter app with environment variables and built-in hot reload
echo -e "${BLUE}🔧 Starting Flutter app with built-in hot reload...${NC}"
echo -e "${YELLOW}🔍 Environment Variables:${NC}"
echo -e "  SUPABASE_URL: ${SUPABASE_URL}"
echo -e "  SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..." # Show only first 20 chars for security
echo -e "  GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}"
echo -e "  APP_URL: ${APP_URL}"
echo -e "  FLUTTER_ENV: ${FLUTTER_ENV}"
echo -e ""

flutter run -d chrome \
  --web-port=59641 \
  --web-browser-flag="--profile-directory=Default" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=APP_URL="$APP_URL" \
  --dart-define=FLUTTER_ENV="$FLUTTER_ENV"

echo -e "${GREEN}✅ Flutter development session ended${NC}"