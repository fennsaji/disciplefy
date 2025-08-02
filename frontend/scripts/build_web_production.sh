#!/bin/bash

# Flutter Web Production Build Script
# This script builds the Flutter app for production deployment

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Flutter Web Production Build...${NC}"

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo -e "${RED}❌ .env.production file not found!${NC}"
    echo "Please create .env.production file with your production environment variables."
    exit 1
fi

# Load environment variables from .env.production
source .env.production

# Validate required environment variables
if [ -z "$SUPABASE_URL" ]; then
    echo -e "${RED}❌ SUPABASE_URL is required in .env.production${NC}"
    exit 1
fi

if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo -e "${RED}❌ SUPABASE_ANON_KEY is required in .env.production${NC}"
    exit 1
fi

if [ -z "$GOOGLE_CLIENT_ID" ]; then
    echo -e "${RED}❌ GOOGLE_CLIENT_ID is required in .env.production${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment variables validated${NC}"

# Get Flutter dependencies
echo -e "${BLUE}📦 Installing Flutter dependencies...${NC}"
flutter pub get

# Clean previous builds
echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean
flutter pub get

# Display production build info
echo -e "${GREEN}🏗️ Building Flutter for production!${NC}"
echo -e "${BLUE}📍 Environment: PRODUCTION${NC}"
echo -e "${BLUE}🌐 Supabase URL: $SUPABASE_URL${NC}"
echo -e "${BLUE}🔑 Google Client ID: $GOOGLE_CLIENT_ID${NC}"
echo -e ""

# Build Flutter app for production with environment variables
echo -e "${BLUE}🔧 Building Flutter web app for production...${NC}"
flutter build web \
  --release \
  --web-renderer canvaskit \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=APPLE_CLIENT_ID="$APPLE_CLIENT_ID" \
  --dart-define=APP_URL="$APP_URL" \
  --dart-define=FLUTTER_ENV="production" \
  --dart-define=LOG_LEVEL="info"

echo -e "${GREEN}✅ Production build completed successfully!${NC}"
echo -e "${BLUE}📁 Build output: build/web/${NC}"
echo -e "${YELLOW}🚀 Ready for deployment to production!${NC}"