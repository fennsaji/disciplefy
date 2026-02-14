#!/bin/bash

# Flutter Android Local Development Script with Hot Reload
# This script loads environment variables from specified env file and runs the Flutter app on Android device/emulator
# Flutter provides hot reload out of the box - no additional file watching needed!
# Usage: ./run-android-local.sh [env-file] [device-id]
# Default: ./run-android-local.sh (uses .env.android and shows device selection if multiple devices)
# Examples: ./run-android-local.sh .env.dev
#           ./run-android-local.sh .env.local emulator-5554
#           ./run-android-local.sh .env.local (interactive device selection)

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default to .env.android if no parameter provided
ENV_FILE="${1:-.env.android}"
DEVICE_ID_ARG="${2:-}"

echo -e "${BLUE}🚀 Starting Flutter Android Local Development...${NC}"
echo -e "${BLUE}📄 Using environment file: ${ENV_FILE}${NC}"

# Check if specified env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file '$ENV_FILE' not found!${NC}"
    echo "Available environment files:"
    ls -la .env* 2>/dev/null || echo "No .env* files found"
    echo ""
    echo "Usage: $0 [env-file] [device-id]"
    echo "Examples:"
    echo "  $0                 # Uses .env.android (default) and shows device selection"
    echo "  $0 .env.dev        # Uses .env.dev and shows device selection"
    echo "  $0 .env.local emulator-5554  # Uses specific device"
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

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo -e "${RED}❌ Android SDK platform-tools (adb) not found!${NC}"
    echo "Please ensure Android SDK is installed."
    echo ""
    echo "Checked locations:"
    echo "  • \$ANDROID_HOME/platform-tools/adb"
    echo "  • \$HOME/Library/Android/sdk/platform-tools/adb (macOS)"
    echo "  • \$HOME/Android/Sdk/platform-tools/adb (Linux)"
    echo ""
    echo "If Android SDK is installed elsewhere, set ANDROID_HOME:"
    echo "  export ANDROID_HOME=/path/to/android/sdk"
    exit 1
fi

echo -e "${GREEN}✅ Android SDK found: ${ANDROID_HOME}${NC}"

# Function to detect device type (emulator vs physical device)
is_emulator() {
    local device_id="$1"
    [[ "$device_id" == emulator-* ]] && return 0 || return 1
}

# Function to get device name from flutter devices
get_device_name() {
    local device_id="$1"
    local name=$(flutter devices 2>/dev/null | grep -A1 "$device_id" | grep -o "^[^•]*" | head -n1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [ -z "$name" ]; then
        # Fallback to adb if flutter devices doesn't work
        if is_emulator "$device_id"; then
            name="Android Emulator"
        else
            name=$(adb -s "$device_id" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || echo "Physical Device")
        fi
    fi
    echo "$name"
}

# Detect all connected devices (both physical and emulators)
echo -e "${BLUE}🔍 Detecting Android devices...${NC}"

# Get list of connected devices from adb
ADB_DEVICES=$(adb devices 2>/dev/null | grep -v "List of devices" | grep "device$" | awk '{print $1}')

if [ -z "$ADB_DEVICES" ]; then
    echo -e "${YELLOW}📱 No connected devices found. Checking available emulators...${NC}"

    # Check if emulator command is available
    if ! command -v emulator &> /dev/null; then
        echo -e "${RED}❌ No devices connected and emulator command not found!${NC}"
        echo "Please either:"
        echo "  1. Connect a physical Android device via USB"
        echo "  2. Install Android SDK with emulator support"
        exit 1
    fi

    # Get list of available emulators
    AVAILABLE_EMULATORS=$(emulator -list-avds 2>/dev/null)

    if [ -z "$AVAILABLE_EMULATORS" ]; then
        echo -e "${RED}❌ No connected devices and no emulators found!${NC}"
        echo "Please either:"
        echo "  1. Connect a physical Android device via USB and enable USB debugging"
        echo "  2. Create an emulator using Android Studio or avdmanager"
        exit 1
    fi

    # Show available emulators and let user choose
    echo -e "${CYAN}Available emulators:${NC}"
    local idx=1
    declare -a EMULATOR_ARRAY
    while IFS= read -r emulator; do
        echo -e "  ${GREEN}${idx})${NC} ${emulator}"
        EMULATOR_ARRAY[$idx]="$emulator"
        ((idx++))
    done <<< "$AVAILABLE_EMULATORS"

    echo ""
    read -p "Select emulator to start (1-$((idx-1))): " selection

    if [ -z "$selection" ] || [ "$selection" -lt 1 ] || [ "$selection" -ge "$idx" ]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
    fi

    SELECTED_EMULATOR="${EMULATOR_ARRAY[$selection]}"
    echo -e "${YELLOW}📱 Starting emulator: ${SELECTED_EMULATOR}${NC}"
    echo -e "${YELLOW}⏳ This may take a minute...${NC}"

    # Start emulator in background
    emulator -avd "$SELECTED_EMULATOR" -no-snapshot-load > /dev/null 2>&1 &
    EMULATOR_PID=$!

    # Wait for emulator to boot
    echo -e "${BLUE}⏳ Waiting for emulator to boot...${NC}"
    adb wait-for-device

    # Wait for boot to complete
    while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
        sleep 2
    done

    echo -e "${GREEN}✅ Emulator started successfully${NC}"

    # Get the newly started emulator's device ID
    DEVICE_ID=$(adb devices | grep -v "List of devices" | grep "device$" | awk '{print $1}' | head -n 1)
else
    # Devices are already connected
    DEVICE_COUNT=$(echo "$ADB_DEVICES" | wc -l | tr -d ' ')

    if [ -n "$DEVICE_ID_ARG" ]; then
        # User specified a device ID
        if echo "$ADB_DEVICES" | grep -q "^${DEVICE_ID_ARG}$"; then
            DEVICE_ID="$DEVICE_ID_ARG"
            echo -e "${GREEN}✅ Using specified device: ${DEVICE_ID}${NC}"
        else
            echo -e "${RED}❌ Device '$DEVICE_ID_ARG' not found!${NC}"
            echo "Connected devices:"
            echo "$ADB_DEVICES"
            exit 1
        fi
    elif [ "$DEVICE_COUNT" -eq 1 ]; then
        # Only one device - auto-select it
        DEVICE_ID=$(echo "$ADB_DEVICES" | head -n 1)
        DEVICE_NAME=$(get_device_name "$DEVICE_ID")
        DEVICE_TYPE=$(is_emulator "$DEVICE_ID" && echo "Emulator" || echo "Physical Device")
        echo -e "${GREEN}✅ Auto-selected device: ${DEVICE_NAME} (${DEVICE_ID}) - ${DEVICE_TYPE}${NC}"
    else
        # Multiple devices - show selection menu
        echo -e "${CYAN}📱 Multiple devices detected. Please select one:${NC}"
        echo ""

        local idx=1
        declare -a DEVICE_ID_ARRAY
        while IFS= read -r device_id; do
            DEVICE_NAME=$(get_device_name "$device_id")
            DEVICE_TYPE=$(is_emulator "$device_id" && echo "Emulator" || echo "Physical Device")
            echo -e "  ${GREEN}${idx})${NC} ${DEVICE_NAME}"
            echo -e "     ${BLUE}ID:${NC} ${device_id}"
            echo -e "     ${BLUE}Type:${NC} ${DEVICE_TYPE}"
            echo ""
            DEVICE_ID_ARRAY[$idx]="$device_id"
            ((idx++))
        done <<< "$ADB_DEVICES"

        read -p "Select device (1-$((idx-1))): " selection

        if [ -z "$selection" ] || [ "$selection" -lt 1 ] || [ "$selection" -ge "$idx" ]; then
            echo -e "${RED}❌ Invalid selection${NC}"
            exit 1
        fi

        DEVICE_ID="${DEVICE_ID_ARRAY[$selection]}"
        DEVICE_NAME=$(get_device_name "$DEVICE_ID")
        DEVICE_TYPE=$(is_emulator "$DEVICE_ID" && echo "Emulator" || echo "Physical Device")
        echo -e "${GREEN}✅ Selected: ${DEVICE_NAME} (${DEVICE_ID}) - ${DEVICE_TYPE}${NC}"
    fi
fi

# Verify device is ready
if [ -z "$DEVICE_ID" ]; then
    echo -e "${RED}❌ Failed to get device ID${NC}"
    exit 1
fi

# For emulators, ensure they're fully booted
if is_emulator "$DEVICE_ID"; then
    echo -e "${BLUE}⏳ Ensuring emulator is fully booted...${NC}"
    while [ "$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
        sleep 2
    done
fi

echo -e "${GREEN}✅ Device ready: ${DEVICE_ID}${NC}"

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
DEVICE_NAME=$(get_device_name "$DEVICE_ID")
DEVICE_TYPE=$(is_emulator "$DEVICE_ID" && echo "Emulator" || echo "Physical Device")
echo -e "${BLUE}📱 Device: ${DEVICE_NAME} (${DEVICE_ID}) - ${DEVICE_TYPE}${NC}"
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
