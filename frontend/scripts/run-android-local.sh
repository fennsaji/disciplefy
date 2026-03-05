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

# Detect connected devices AND available emulators (always show both)
echo -e "${BLUE}🔍 Detecting Android devices and available emulators...${NC}"

# Connected ADB devices (physical + already-running emulators)
ADB_DEVICES=$(adb devices 2>/dev/null | grep -v "List of devices" | grep "device$" | awk '{print $1}')

# Available AVDs (all, including ones not yet running)
AVAILABLE_AVDS=""
if command -v emulator &> /dev/null; then
    AVAILABLE_AVDS=$(emulator -list-avds 2>/dev/null || true)
fi

# Which emulator-* IDs are already running in adb?
RUNNING_EMULATOR_IDS=$(echo "$ADB_DEVICES" | grep "^emulator-" || true)

# Build unified menu: entries are "adb:<id>" or "avd:<name>"
declare -a MENU_IDS
declare -a MENU_LABELS
menu_idx=1

# --- Connected ADB devices (physical devices + running emulators) ---
if [ -n "$ADB_DEVICES" ]; then
    while IFS= read -r device_id; do
        [ -z "$device_id" ] && continue
        DEVICE_NAME=$(get_device_name "$device_id")
        if is_emulator "$device_id"; then
            DEVICE_TYPE="Emulator (running)"
        else
            DEVICE_TYPE="Physical Device"
        fi
        MENU_IDS[$menu_idx]="adb:$device_id"
        MENU_LABELS[$menu_idx]="${DEVICE_NAME} | ${DEVICE_TYPE}"
        menu_idx=$((menu_idx + 1))
    done <<< "$ADB_DEVICES"
fi

# --- Available-but-not-yet-running AVDs ---
if [ -n "$AVAILABLE_AVDS" ]; then
    while IFS= read -r avd_name; do
        [ -z "$avd_name" ] && continue

        # Skip if this AVD is already running (matched via ro.kernel.qemu.avd_name)
        already_running=false
        if [ -n "$RUNNING_EMULATOR_IDS" ]; then
            while IFS= read -r emu_id; do
                [ -z "$emu_id" ] && continue
                running_avd=$(adb -s "$emu_id" shell getprop ro.kernel.qemu.avd_name 2>/dev/null | tr -d '\r' || true)
                if [ "$running_avd" = "$avd_name" ]; then
                    already_running=true
                    break
                fi
            done <<< "$RUNNING_EMULATOR_IDS"
        fi

        if [ "$already_running" = false ]; then
            MENU_IDS[$menu_idx]="avd:$avd_name"
            MENU_LABELS[$menu_idx]="${avd_name} | Emulator (not running)"
            menu_idx=$((menu_idx + 1))
        fi
    done <<< "$AVAILABLE_AVDS"
fi

TOTAL_OPTIONS=$((menu_idx - 1))

if [ "$TOTAL_OPTIONS" -eq 0 ]; then
    echo -e "${RED}❌ No connected devices and no emulators found!${NC}"
    echo "Please either:"
    echo "  1. Connect a physical Android device via USB and enable USB debugging"
    echo "  2. Create an emulator using Android Studio or avdmanager"
    exit 1
fi

# --- Resolve device selection ---
SELECTED_ENTRY=""

if [ -n "$DEVICE_ID_ARG" ]; then
    # CLI argument: must be an already-connected ADB device
    if echo "$ADB_DEVICES" | grep -q "^${DEVICE_ID_ARG}$"; then
        SELECTED_ENTRY="adb:$DEVICE_ID_ARG"
        echo -e "${GREEN}✅ Using specified device: ${DEVICE_ID_ARG}${NC}"
    else
        echo -e "${RED}❌ Device '${DEVICE_ID_ARG}' not found in connected devices!${NC}"
        echo "Connected devices:"
        echo "$ADB_DEVICES"
        exit 1
    fi
elif [ "$TOTAL_OPTIONS" -eq 1 ]; then
    # Only one option — auto-select
    SELECTED_ENTRY="${MENU_IDS[1]}"
    echo -e "${GREEN}✅ Auto-selected: ${MENU_LABELS[1]}${NC}"
else
    # Always show unified menu so user can pick any device or emulator
    echo -e "${CYAN}📱 Select a device or emulator:${NC}"
    echo ""
    for i in $(seq 1 $TOTAL_OPTIONS); do
        LABEL="${MENU_LABELS[$i]}"
        ENTRY="${MENU_IDS[$i]}"
        if [[ "$ENTRY" == avd:* ]]; then
            echo -e "  ${YELLOW}${i})${NC} ${LABEL}"
        else
            echo -e "  ${GREEN}${i})${NC} ${LABEL}"
            echo -e "     ${BLUE}ID:${NC} ${ENTRY#adb:}"
        fi
        echo ""
    done

    read -p "Select (1-${TOTAL_OPTIONS}): " selection

    if [ -z "$selection" ] || ! [[ "$selection" =~ ^[0-9]+$ ]] || \
       [ "$selection" -lt 1 ] || [ "$selection" -gt "$TOTAL_OPTIONS" ]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        exit 1
    fi

    SELECTED_ENTRY="${MENU_IDS[$selection]}"
    echo -e "${GREEN}✅ Selected: ${MENU_LABELS[$selection]}${NC}"
fi

# --- Act on selection ---
DEVICE_ID=""

if [[ "$SELECTED_ENTRY" == adb:* ]]; then
    DEVICE_ID="${SELECTED_ENTRY#adb:}"

elif [[ "$SELECTED_ENTRY" == avd:* ]]; then
    AVD_NAME="${SELECTED_ENTRY#avd:}"
    echo -e "${YELLOW}📱 Starting emulator: ${AVD_NAME}${NC}"
    echo -e "${YELLOW}⏳ This may take a minute...${NC}"

    # Snapshot existing device IDs so we can identify the new emulator
    EXISTING_DEVICES=$(adb devices | grep -v "List of devices" | grep "device$" | awk '{print $1}' || true)

    # Launch emulator in background
    emulator -avd "$AVD_NAME" -no-snapshot-load > /dev/null 2>&1 &
    EMULATOR_PID=$!

    # Wait for the new emulator to appear in adb
    echo -e "${BLUE}⏳ Waiting for emulator to appear in adb...${NC}"
    NEW_DEVICE_ID=""
    while [ -z "$NEW_DEVICE_ID" ]; do
        sleep 2
        CURRENT_DEVICES=$(adb devices | grep -v "List of devices" | grep "device$" | awk '{print $1}' || true)
        while IFS= read -r dev; do
            [ -z "$dev" ] && continue
            if ! echo "$EXISTING_DEVICES" | grep -q "^${dev}$"; then
                NEW_DEVICE_ID="$dev"
                break
            fi
        done <<< "$CURRENT_DEVICES"
    done

    DEVICE_ID="$NEW_DEVICE_ID"
    echo -e "${BLUE}⏳ Waiting for emulator to finish booting (${DEVICE_ID})...${NC}"

    while [ "$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
        sleep 2
    done

    echo -e "${GREEN}✅ Emulator started: ${DEVICE_ID}${NC}"
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
