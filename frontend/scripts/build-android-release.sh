#!/bin/bash

# ============================================================================
# Disciplefy Bible Study - Android Release Build Script
# ============================================================================
# This script builds a signed Android App Bundle (AAB) for Play Store release
# 
# Usage: 
#   ./scripts/build-android-release.sh              # Build AAB using .env.production
#   ./scripts/build-android-release.sh apk          # Build APK for direct distribution
#   ./scripts/build-android-release.sh --help       # Show help
#
# Prerequisites:
#   - Flutter SDK installed
#   - Android SDK configured
#   - key.properties file configured (or ANDROID_KEYSTORE_* env vars set)
#   - .env.production file with valid production credentials
# ============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_DIR}/.env.production"
BUILD_TYPE="${1:-appbundle}"  # appbundle (default) or apk

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🚀 Disciplefy Android Release Build${NC}"
echo -e "${BLUE}============================================${NC}"

# Show help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo ""
    echo "Usage: $0 [appbundle|apk]"
    echo ""
    echo "Arguments:"
    echo "  appbundle   Build Android App Bundle for Play Store (default)"
    echo "  apk         Build APK for direct distribution"
    echo ""
    echo "Environment Variables (optional - can also use .env.production):"
    echo "  SUPABASE_URL              - Supabase project URL"
    echo "  SUPABASE_ANON_KEY         - Supabase anonymous key"
    echo "  GOOGLE_CLIENT_ID          - Google OAuth client ID for Android"
    echo "  APP_URL                   - Production app URL"
    echo "  GOOGLE_CLOUD_TTS_API_KEY  - Google Cloud TTS API key"
    echo ""
    exit 0
fi

# Change to project directory
cd "$PROJECT_DIR"
echo -e "${GREEN}📁 Working directory: ${PROJECT_DIR}${NC}"

# Validate build type
if [[ "$BUILD_TYPE" != "appbundle" && "$BUILD_TYPE" != "apk" ]]; then
    echo -e "${RED}❌ Invalid build type: ${BUILD_TYPE}${NC}"
    echo "Use 'appbundle' for Play Store or 'apk' for direct distribution"
    exit 1
fi

# Load environment variables from .env.production if it exists
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}✅ Loading environment from: ${ENV_FILE}${NC}"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${YELLOW}⚠️  No .env.production found. Using environment variables.${NC}"
fi

# Validate required environment variables
echo -e "${BLUE}🔍 Validating environment variables...${NC}"
MISSING_VARS=""
[ -z "$SUPABASE_URL" ] && MISSING_VARS="${MISSING_VARS}  - SUPABASE_URL\n"
[ -z "$SUPABASE_ANON_KEY" ] && MISSING_VARS="${MISSING_VARS}  - SUPABASE_ANON_KEY\n"
[ -z "$GOOGLE_CLIENT_ID" ] && MISSING_VARS="${MISSING_VARS}  - GOOGLE_CLIENT_ID\n"
[ -z "$APP_URL" ] && MISSING_VARS="${MISSING_VARS}  - APP_URL\n"

if [ -n "$MISSING_VARS" ]; then
    echo -e "${RED}❌ Missing required environment variables:${NC}"
    echo -e "${MISSING_VARS}" | sed 's/\\n$//'
    echo ""
    echo "Please set these in .env.production or as environment variables"
    exit 1
fi

echo -e "${GREEN}✅ All required environment variables present${NC}"

# Check for keystore configuration
echo -e "${BLUE}🔐 Checking signing configuration...${NC}"
KEY_PROPERTIES="${PROJECT_DIR}/android/key.properties"

if [ -f "$KEY_PROPERTIES" ]; then
    echo -e "${GREEN}✅ key.properties found${NC}"
else
    echo -e "${YELLOW}⚠️  key.properties not found at ${KEY_PROPERTIES}${NC}"
    echo "The build will proceed, but may use debug signing."
    echo ""
    echo "To create key.properties, create a file with:"
    echo "  storePassword=YOUR_STORE_PASSWORD"
    echo "  keyPassword=YOUR_KEY_PASSWORD"
    echo "  keyAlias=YOUR_KEY_ALIAS"
    echo "  storeFile=upload-keystore.jks"
fi

# Display build configuration
echo ""
echo -e "${BLUE}📋 Build Configuration:${NC}"
echo "  Build Type:     ${BUILD_TYPE}"
echo "  Environment:    ${FLUTTER_ENV:-production}"
echo "  Supabase URL:   ${SUPABASE_URL}"
echo "  App URL:        ${APP_URL}"
echo ""

# Clean previous builds
echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean

# Get dependencies
echo -e "${BLUE}📦 Getting dependencies...${NC}"
flutter pub get

# Get version from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
echo -e "${GREEN}📌 Building version: ${VERSION}${NC}"

# Build the release
echo ""
echo -e "${BLUE}🏗️  Building ${BUILD_TYPE}...${NC}"
echo -e "${YELLOW}This may take a few minutes...${NC}"
echo ""

if [ "$BUILD_TYPE" == "appbundle" ]; then
    flutter build appbundle --release \
        --dart-define=SUPABASE_URL="$SUPABASE_URL" \
        --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
        --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
        --dart-define=APP_URL="$APP_URL" \
        --dart-define=FLUTTER_ENV="${FLUTTER_ENV:-production}" \
        ${GOOGLE_CLOUD_TTS_API_KEY:+--dart-define=GOOGLE_CLOUD_TTS_API_KEY="$GOOGLE_CLOUD_TTS_API_KEY"}
    
    OUTPUT_FILE="${PROJECT_DIR}/build/app/outputs/bundle/release/app-release.aab"
    OUTPUT_NAME="app-release.aab"
else
    flutter build apk --release \
        --dart-define=SUPABASE_URL="$SUPABASE_URL" \
        --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
        --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
        --dart-define=APP_URL="$APP_URL" \
        --dart-define=FLUTTER_ENV="${FLUTTER_ENV:-production}" \
        ${GOOGLE_CLOUD_TTS_API_KEY:+--dart-define=GOOGLE_CLOUD_TTS_API_KEY="$GOOGLE_CLOUD_TTS_API_KEY"}
    
    OUTPUT_FILE="${PROJECT_DIR}/build/app/outputs/flutter-apk/app-release.apk"
    OUTPUT_NAME="app-release.apk"
fi

# Verify output
if [ -f "$OUTPUT_FILE" ]; then
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}✅ BUILD SUCCESSFUL!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "${BLUE}📦 Output:${NC}"
    echo "  File: ${OUTPUT_FILE}"
    echo "  Size: ${FILE_SIZE}"
    echo "  Version: ${VERSION}"
    echo ""
    
    if [ "$BUILD_TYPE" == "appbundle" ]; then
        echo -e "${BLUE}📤 Next Steps for Play Store:${NC}"
        echo "  1. Go to Google Play Console"
        echo "  2. Select your app → Release → Testing → Internal testing"
        echo "  3. Create new release and upload: ${OUTPUT_NAME}"
        echo "  4. Add release notes and submit"
    else
        echo -e "${BLUE}📤 Next Steps for APK distribution:${NC}"
        echo "  1. Upload to Firebase App Distribution, or"
        echo "  2. Share directly with testers"
    fi
    echo ""
else
    echo -e "${RED}❌ Build failed - output file not found${NC}"
    exit 1
fi
