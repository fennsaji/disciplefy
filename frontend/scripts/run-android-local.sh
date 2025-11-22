#!/bin/bash

# Flutter Android Local Development Script with Hot Reload
# This script loads environment variables from specified env file and runs the Flutter app on Android emulator
# Flutter provides hot reload out of the box - no additional file watching needed!
# Usage: ./run-android-local.sh [env-file] [emulator-name]
# Default: ./run-android-local.sh (uses .env.android and auto-selects emulator)
# Examples: ./run-android-local.sh .env.dev
#           ./run-android-local.sh .env.local Pixel_3a_API_34_extension_level_7_arm64-v8a

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default to .env.android if no parameter provided
ENV_FILE="${1:-.env.android}"
EMULATOR_NAME="${2:-Pixel_3a_API_34_GooglePlay}"

echo -e "${BLUE}🚀 Starting Flutter Android Local Development...${NC}"
echo -e "${BLUE}📄 Using environment file: ${ENV_FILE}${NC}"

# Check if specified env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file '$ENV_FILE' not found!${NC}"
    echo "Available environment files:"
    ls -la .env* 2>/dev/null || echo "No .env* files found"
    echo ""
    echo "Usage: $0 [env-file] [emulator-name]"
    echo "Examples:"
    echo "  $0                 # Uses .env.android (default) and auto-selects emulator"
    echo "  $0 .env.dev        # Uses .env.dev and auto-selects emulator"
    echo "  $0 .env.local Pixel_3a_API_34_extension_level_7_arm64-v8a"
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
    echo "" >&2
    echo -e "${YELLOW}Please ensure the following variables are set in ${ENV_FILE}:${NC}" >&2
    echo "  SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_CLIENT_ID, APP_URL, FLUTTER_ENV" >&2
    exit 1
fi

echo -e "${GREEN}✅ All required environment variables loaded${NC}"

# Auto-detect Android SDK if ANDROID_HOME is not set
if [ -z "$ANDROID_HOME" ]; then
    # Try common locations
    if [ -d "$HOME/Library/Android/sdk" ]; then
        export ANDROID_HOME="$HOME/Library/Android/sdk"
        echo -e "${YELLOW}⚙️  Auto-detected Android SDK: ${ANDROID_HOME}${NC}"
    elif [ -d "$HOME/Android/Sdk" ]; then
        export ANDROID_HOME="$HOME/Android/Sdk"
        echo -e "${YELLOW}⚙️  Auto-detected Android SDK: ${ANDROID_HOME}${NC}"
    fi
fi

# Add Android SDK tools to PATH
if [ -n "$ANDROID_HOME" ]; then
    export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$PATH"
fi

# Check if Android SDK is available
if ! command -v emulator &> /dev/null; then
    echo -e "${RED}❌ Android SDK emulator not found!${NC}"
    echo "Please ensure Android SDK is installed."
    echo ""
    echo "Checked locations:"
    echo "  • \$ANDROID_HOME/emulator/emulator"
    echo "  • \$HOME/Library/Android/sdk/emulator/emulator (macOS)"
    echo "  • \$HOME/Android/Sdk/emulator/emulator (Linux)"
    echo ""
    echo "If Android SDK is installed elsewhere, set ANDROID_HOME:"
    echo "  export ANDROID_HOME=/path/to/android/sdk"
    exit 1
fi

echo -e "${GREEN}✅ Android SDK found: ${ANDROID_HOME}${NC}"

# Get list of available emulators
echo -e "${BLUE}🔍 Checking available Android emulators...${NC}"
AVAILABLE_EMULATORS=$(emulator -list-avds 2>/dev/null)

if [ -z "$AVAILABLE_EMULATORS" ]; then
    echo -e "${RED}❌ No Android emulators found!${NC}"
    echo "Please create an emulator using Android Studio or avdmanager."
    exit 1
fi

# Select emulator
if [ -z "$EMULATOR_NAME" ]; then
    # Auto-select first available emulator
    EMULATOR_NAME=$(echo "$AVAILABLE_EMULATORS" | head -n 1)
    echo -e "${GREEN}✅ Auto-selected emulator: ${EMULATOR_NAME}${NC}"
else
    # Verify specified emulator exists
    if ! echo "$AVAILABLE_EMULATORS" | grep -q "^${EMULATOR_NAME}$"; then
        echo -e "${RED}❌ Emulator '$EMULATOR_NAME' not found!${NC}"
        echo "Available emulators:"
        echo "$AVAILABLE_EMULATORS"
        exit 1
    fi
    echo -e "${GREEN}✅ Using specified emulator: ${EMULATOR_NAME}${NC}"
fi

# Check if emulator is already running
echo -e "${BLUE}🔍 Checking emulator status...${NC}"
RUNNING_DEVICES=$(adb devices 2>/dev/null | grep -v "List of devices" | grep "device$" | wc -l)

if [ "$RUNNING_DEVICES" -eq 0 ]; then
    echo -e "${YELLOW}📱 Starting Android emulator: ${EMULATOR_NAME}${NC}"
    echo -e "${YELLOW}⏳ This may take a minute...${NC}"

    # Start emulator in background
    emulator -avd "$EMULATOR_NAME" -no-snapshot-load > /dev/null 2>&1 &
    EMULATOR_PID=$!

    # Wait for emulator to boot
    echo -e "${BLUE}⏳ Waiting for emulator to boot...${NC}"
    adb wait-for-device

    # Wait for boot to complete
    while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
        sleep 2
    done

    echo -e "${GREEN}✅ Emulator started successfully${NC}"
else
    echo -e "${GREEN}✅ Emulator already running${NC}"
fi

# Get device ID
DEVICE_ID=$(adb devices | grep -v "List of devices" | grep "device$" | awk '{print $1}' | head -n 1)
echo -e "${GREEN}✅ Using device: ${DEVICE_ID}${NC}"

# Check if Supabase is accessible
# Note: If using Android emulator address (10.0.2.2), test with localhost (127.0.0.1) instead
# because 10.0.2.2 only resolves from within the emulator
CHECK_URL="${SUPABASE_URL}"
if [[ "$SUPABASE_URL" == *"10.0.2.2"* ]]; then
    CHECK_URL="${SUPABASE_URL//10.0.2.2/127.0.0.1}"
    echo -e "${BLUE}🔗 Testing Supabase connection: ${SUPABASE_URL} (checking via 127.0.0.1)${NC}"
else
    echo -e "${BLUE}🔗 Testing Supabase connection: ${SUPABASE_URL}${NC}"
fi

if ! curl -s --connect-timeout 5 --max-time 10 "${CHECK_URL}/rest/v1/" > /dev/null 2>&1; then
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
echo -e "${BLUE}📱 Device: ${DEVICE_ID}${NC}"
echo -e "${BLUE}🔥 Hot reload: ${GREEN}ENABLED (built-in)${NC}"
echo -e ""
echo -e "${YELLOW}💬 Flutter Commands (once running):${NC}"
echo -e "  ${GREEN}r${NC} - Hot reload (apply changes instantly)"
echo -e "  ${GREEN}R${NC} - Hot restart (restart the app completely)"
echo -e "  ${GREEN}q${NC} - Quit development server"
echo -e "  ${GREEN}h${NC} - Show help"
echo -e "  ${GREEN}c${NC} - Clear console"
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

flutter run -d "$DEVICE_ID" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=APP_URL="$APP_URL" \
  --dart-define=FLUTTER_ENV="$FLUTTER_ENV"

echo -e "${GREEN}✅ Flutter development session ended${NC}"
