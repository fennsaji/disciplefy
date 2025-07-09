#!/bin/bash

# Flutter Web Local Development Script
# This script loads environment variables from .env.local and runs the Flutter app

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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

# Run Flutter app with environment variables
echo -e "${BLUE}🔧 Starting Flutter app with local configuration...${NC}"
flutter run -d chrome \
  --web-port=59641 \
  --web-browser-flag="--profile-directory=Default" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=APPLE_CLIENT_ID="$APPLE_CLIENT_ID" \
  --dart-define=FLUTTER_ENV="$FLUTTER_ENV" \
  --dart-define=LOG_LEVEL="$LOG_LEVEL"

echo -e "${GREEN}✅ Flutter app started successfully!${NC}"