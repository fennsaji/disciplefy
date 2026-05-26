#!/bin/bash

# Flutter iOS Local Development Script with Hot Reload
# This script loads environment variables and runs the Flutter app on iOS Simulator
# Usage: ./run-ios-local.sh [env-file] [device-id]
# Default: ./run-ios-local.sh (uses .env.local and auto-selects simulator)

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default to .env.local (iOS simulator shares Mac's localhost)
ENV_FILE="${1:-.env.local}"
DEVICE_ID_ARG="${2:-}"

echo -e "${BLUE}🚀 Starting Flutter iOS Local Development...${NC}"
echo -e "${BLUE}📄 Using environment file: ${ENV_FILE}${NC}"

# Check if specified env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file '$ENV_FILE' not found!${NC}"
    echo "Available environment files:"
    ls -la .env* 2>/dev/null || echo "No .env* files found"
    exit 1
fi

# Load environment variables from specified file
echo -e "${GREEN}✅ Loading environment from: ${ENV_FILE}${NC}"
source "$ENV_FILE"

# Validate required environment variables
MISSING_VARS=""
[ -z "$SUPABASE_URL" ] && MISSING_VARS="${MISSING_VARS}  - SUPABASE_URL\n"
[ -z "$SUPABASE_ANON_KEY" ] && MISSING_VARS="${MISSING_VARS}  - SUPABASE_ANON_KEY\n"
[ -z "$GOOGLE_CLIENT_ID" ] && MISSING_VARS="${MISSING_VARS}  - GOOGLE_CLIENT_ID\n"
[ -z "$APP_URL" ] && MISSING_VARS="${MISSING_VARS}  - APP_URL\n"
[ -z "$FLUTTER_ENV" ] && MISSING_VARS="${MISSING_VARS}  - FLUTTER_ENV\n"

if [ -n "$MISSING_VARS" ]; then
    echo -e "${RED}❌ Missing required environment variables in ${ENV_FILE}:${NC}" >&2
    echo -e "${MISSING_VARS}" | sed 's/\\n$//' >&2
    exit 1
fi

echo -e "${GREEN}✅ All required environment variables loaded${NC}"

# Check if Xcode is available
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode not found! Please install Xcode from the App Store.${NC}"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo -e "${GREEN}✅ ${XCODE_VERSION}${NC}"

# Resolve device
if [ -n "$DEVICE_ID_ARG" ]; then
    DEVICE_ID="$DEVICE_ID_ARG"
    echo -e "${GREEN}✅ Using specified device: ${DEVICE_ID}${NC}"
else
    # Auto-detect: prefer booted simulator, else boot the first available iPhone
    BOOTED_ID=$(xcrun simctl list devices booted -j 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('state') == 'Booted' and 'iPhone' in d.get('name', ''):
            print(d['udid'])
            sys.exit(0)
" 2>/dev/null || true)

    if [ -n "$BOOTED_ID" ]; then
        DEVICE_NAME=$(xcrun simctl list devices booted | grep "$BOOTED_ID" | sed 's/ (.*//;s/^[[:space:]]*//')
        DEVICE_ID="$BOOTED_ID"
        echo -e "${GREEN}✅ Using booted simulator: ${DEVICE_NAME}${NC}"
    else
        # Find first available iPhone simulator
        FIRST_IPHONE=$(xcrun simctl list devices available -j 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in sorted(data.get('devices', {}).items(), reverse=True):
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d.get('isAvailable') and 'iPhone' in d.get('name', ''):
            print(d['udid'] + '|' + d['name'])
            sys.exit(0)
" 2>/dev/null || true)

        if [ -z "$FIRST_IPHONE" ]; then
            echo -e "${RED}❌ No iPhone simulator found! Create one in Xcode → Settings → Platforms.${NC}"
            exit 1
        fi

        DEVICE_ID=$(echo "$FIRST_IPHONE" | cut -d'|' -f1)
        DEVICE_NAME=$(echo "$FIRST_IPHONE" | cut -d'|' -f2)

        echo -e "${YELLOW}📱 Booting simulator: ${DEVICE_NAME}...${NC}"
        xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
        open -a Simulator
        echo -e "${GREEN}✅ Simulator booted: ${DEVICE_NAME}${NC}"
    fi
fi

# Check if Supabase is accessible (iOS simulator uses Mac's localhost directly)
echo -e "${BLUE}🔗 Testing Supabase connection: ${SUPABASE_URL}${NC}"
if ! curl -s --connect-timeout 5 --max-time 10 "${SUPABASE_URL}/rest/v1/" > /dev/null 2>&1; then
    echo -e "${RED}❌ Supabase instance is not accessible!${NC}"
    echo "Please check:"
    echo "  • If using local Supabase: cd ../backend && supabase start"
    echo "  • Current SUPABASE_URL: ${SUPABASE_URL}"
    exit 1
fi

echo -e "${GREEN}✅ Supabase instance is accessible${NC}"

# Get Flutter dependencies
echo -e "${BLUE}📦 Installing Flutter dependencies...${NC}"
flutter pub get

# Display development info
echo -e "${GREEN}🎉 Starting Flutter with hot reload enabled!${NC}"
echo -e "${BLUE}📱 Device: iOS Simulator (${DEVICE_ID})${NC}"
echo -e "${BLUE}🔥 Hot reload: ${GREEN}ENABLED (built-in)${NC}"
echo -e ""
echo -e "${YELLOW}💬 Flutter Commands (once running):${NC}"
echo -e "  ${GREEN}r${NC} - Hot reload (apply changes instantly)"
echo -e "  ${GREEN}R${NC} - Hot restart (restart the app completely)"
echo -e "  ${GREEN}q${NC} - Quit development server"
echo -e "  ${GREEN}h${NC} - Show help"
echo -e "  ${GREEN}c${NC} - Clear console"
echo -e ""
echo -e "${YELLOW}💡 Just save your files - Flutter will hot reload automatically!${NC}"
echo -e ""

# Run Flutter app with environment variables
echo -e "${BLUE}🔧 Starting Flutter app...${NC}"
echo -e "${YELLOW}🔍 Environment Variables:${NC}"
echo -e "  SUPABASE_URL: ${SUPABASE_URL}"
echo -e "  SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."
echo -e "  GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}"
echo -e "  APP_URL: ${APP_URL}"
echo -e "  FLUTTER_ENV: ${FLUTTER_ENV}"
echo -e ""

flutter run -d "$DEVICE_ID" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=APP_URL="$APP_URL" \
  --dart-define=FLUTTER_ENV="$FLUTTER_ENV" \
  --dart-define=GOOGLE_CLOUD_TTS_API_KEY="$GOOGLE_CLOUD_TTS_API_KEY" \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_APP_ID="$FIREBASE_APP_ID" \
  --dart-define=FIREBASE_MEASUREMENT_ID="$FIREBASE_MEASUREMENT_ID" \
  --dart-define=RAZORPAY_KEY_ID="$RAZORPAY_KEY_ID"

echo -e "${GREEN}✅ Flutter development session ended${NC}"
