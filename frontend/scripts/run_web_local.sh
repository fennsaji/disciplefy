#!/bin/bash

# Flutter Web Local Development Script with Hot Reload
# This script loads environment variables from .env.local and runs the Flutter app
# Flutter provides hot reload out of the box - no additional file watching needed!

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Flutter Web Local Development...${NC}"

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo -e "${RED}❌ .env.local file not found!${NC}"
    echo "Please create .env.local file with your environment variables."
    exit 1
fi

# Load environment variables from .env.local
source .env.local

# Check if Supabase is running locally
if ! curl -s http://127.0.0.1:54321/health > /dev/null 2>&1; then
    echo -e "${RED}❌ Supabase local instance is not running!${NC}"
    echo "Please start Supabase first:"
    echo "  cd ../backend && supabase start"
    exit 1
fi

echo -e "${GREEN}✅ Supabase local instance is running${NC}"

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
flutter run -d chrome \
  --web-port=59641 \
  --web-browser-flag="--profile-directory=Default" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=APPLE_CLIENT_ID="$APPLE_CLIENT_ID" \
  --dart-define=APP_URL="$APP_URL" \
  --dart-define=FLUTTER_ENV="$FLUTTER_ENV" \
  --dart-define=LOG_LEVEL="$LOG_LEVEL"

echo -e "${GREEN}✅ Flutter development session ended${NC}"