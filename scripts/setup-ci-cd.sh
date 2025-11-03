#!/bin/bash

# Simplified CI/CD Setup Helper Script
# This version reads Firebase JSON from a file instead of paste

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Disciplefy CI/CD Setup Helper (Simplified)${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -d "frontend/android" ]; then
    echo -e "${RED}❌ Error: Please run this script from the project root directory${NC}"
    exit 1
fi

# Find keytool from Android Studio or system
KEYTOOL=""
if [ -f "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" ]; then
    KEYTOOL="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
    echo -e "${GREEN}✅ Found keytool in Android Studio${NC}"
elif command -v keytool &> /dev/null; then
    KEYTOOL="keytool"
    echo -e "${GREEN}✅ Found keytool in system PATH${NC}"
else
    echo -e "${RED}❌ Error: keytool not found!${NC}"
    echo -e "${YELLOW}Please install JDK or Android Studio to continue.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📋 Step 1: Android Keystore${NC}"
echo -e "${BLUE}===========================${NC}"
echo ""

KEYSTORE_PATH="frontend/android/app/upload-keystore.jks"

if [ -f "$KEYSTORE_PATH" ]; then
    echo -e "${GREEN}✅ Found existing keystore at: $KEYSTORE_PATH${NC}"
    read -p "Do you want to use this keystore? (y/n): " use_existing

    if [ "$use_existing" != "y" ]; then
        echo -e "${YELLOW}Creating new keystore...${NC}"
        rm "$KEYSTORE_PATH"
        cd frontend/android/app
        "$KEYTOOL" -genkey -v -keystore upload-keystore.jks -keyalg RSA \
          -keysize 2048 -validity 10000 -alias disciplefy-upload-key
        cd ../../..
    fi
else
    echo -e "${YELLOW}No keystore found. Generating new keystore...${NC}"
    cd frontend/android/app
    "$KEYTOOL" -genkey -v -keystore upload-keystore.jks -keyalg RSA \
      -keysize 2048 -validity 10000 -alias disciplefy-upload-key
    cd ../../..
fi

# Convert keystore to base64
echo ""
echo -e "${GREEN}✅ Keystore ready!${NC}"
echo -e "${BLUE}Converting keystore to base64...${NC}"

if command -v base64 &> /dev/null; then
    KEYSTORE_BASE64=$(base64 -i "$KEYSTORE_PATH" | tr -d '\n')
    echo -e "${GREEN}✅ Base64 conversion complete${NC}"
else
    echo -e "${RED}❌ base64 command not found${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📋 Step 2: Collect Configuration${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

read -p "Enter your keystore password: " -s KEYSTORE_PASSWORD
echo ""

read -p "Enter your key password (press Enter if same as keystore): " -s KEY_PASSWORD
echo ""
if [ -z "$KEY_PASSWORD" ]; then
    KEY_PASSWORD="$KEYSTORE_PASSWORD"
fi

echo ""
read -p "Enter DEV_SUPABASE_URL (default: http://10.0.2.2:54321): " DEV_SUPABASE_URL
DEV_SUPABASE_URL=${DEV_SUPABASE_URL:-http://10.0.2.2:54321}

read -p "Enter DEV_SUPABASE_ANON_KEY: " DEV_SUPABASE_ANON_KEY

read -p "Enter DEV_GOOGLE_CLIENT_ID: " DEV_GOOGLE_CLIENT_ID

read -p "Enter DEV_APP_URL (default: http://localhost:59641): " DEV_APP_URL
DEV_APP_URL=${DEV_APP_URL:-http://localhost:59641}

read -p "Enter FIREBASE_ANDROID_APP_ID (format: 1:xxx:android:xxx): " FIREBASE_APP_ID

echo ""
echo -e "${YELLOW}Enter the FULL PATH to your Firebase service account JSON file:${NC}"
echo -e "${YELLOW}Example: /Users/fennsaji/Downloads/firebase-adminsdk.json${NC}"
read -p "Path: " FIREBASE_JSON_PATH

if [ ! -f "$FIREBASE_JSON_PATH" ]; then
    echo -e "${RED}❌ Error: File not found at: $FIREBASE_JSON_PATH${NC}"
    exit 1
fi

FIREBASE_JSON=$(cat "$FIREBASE_JSON_PATH")
echo -e "${GREEN}✅ Firebase service account JSON loaded${NC}"

# Generate secrets summary file
echo ""
echo -e "${BLUE}📋 Step 3: Generating Secrets Summary${NC}"
echo -e "${BLUE}=====================================${NC}"

SECRETS_FILE="github-secrets-$(date +%Y%m%d-%H%M%S).txt"

cat > "$SECRETS_FILE" << EOF
# GitHub Secrets for CI/CD
# Generated: $(date)
#
# ⚠️  IMPORTANT: This file contains sensitive information!
# - Do NOT commit this to git
# - Store it securely (password manager)
# - Delete after adding to GitHub

========================================
Android Signing Secrets
========================================

ANDROID_KEYSTORE_BASE64:
$KEYSTORE_BASE64

ANDROID_KEYSTORE_PASSWORD:
$KEYSTORE_PASSWORD

ANDROID_KEY_PASSWORD:
$KEY_PASSWORD

ANDROID_KEY_ALIAS:
disciplefy-upload-key

========================================
Development Environment Secrets
========================================

DEV_SUPABASE_URL:
$DEV_SUPABASE_URL

DEV_SUPABASE_ANON_KEY:
$DEV_SUPABASE_ANON_KEY

DEV_GOOGLE_CLIENT_ID:
$DEV_GOOGLE_CLIENT_ID

DEV_APP_URL:
$DEV_APP_URL

========================================
Firebase App Distribution Secrets
========================================

FIREBASE_ANDROID_APP_ID:
$FIREBASE_APP_ID

FIREBASE_SERVICE_ACCOUNT_JSON:
$FIREBASE_JSON

========================================
EOF

echo -e "${GREEN}✅ Secrets summary saved to: ${SECRETS_FILE}${NC}"
echo ""

echo -e "${BLUE}📋 Step 4: Next Steps${NC}"
echo -e "${BLUE}====================${NC}"
echo ""
echo -e "${GREEN}1. Add secrets to GitHub:${NC}"
echo -e "   Go to: https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions"
echo -e "   Click 'New repository secret' for each secret in ${SECRETS_FILE}"
echo ""
echo -e "${GREEN}2. Set up Firebase App Distribution:${NC}"
echo -e "   - Go to Firebase Console → App Distribution"
echo -e "   - Create a tester group named 'testers'"
echo -e "   - Add tester email addresses to this group"
echo ""
echo -e "${GREEN}3. Test the workflow:${NC}"
echo -e "   - Push to development branch or manually trigger the workflow"
echo -e "   - Check GitHub Actions tab for build status"
echo ""
echo -e "${GREEN}4. Secure this file:${NC}"
echo -e "   - Store ${SECRETS_FILE} in your password manager"
echo -e "   - Then delete it: rm ${SECRETS_FILE}"
echo ""
echo -e "${YELLOW}⚠️  Remember: NEVER commit ${SECRETS_FILE} or the keystore to git!${NC}"
echo ""
echo -e "${BLUE}✨ Setup complete! Happy deploying!${NC}"
