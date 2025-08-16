#!/bin/bash

# Flutter Web Network Development Script
# This script runs Flutter web server accessible from local network (LAN/WiFi)
# Perfect for testing on mobile devices without USB connection
# Usage: ./run-web-network.sh [env-file] [port]
# Default: ./run-web-network.sh .env.local 8080
# Examples:
#   ./run-web-network.sh                    # Uses .env.local on port 8080
#   ./run-web-network.sh .env.dev           # Uses .env.dev on port 8080
#   ./run-web-network.sh .env.local 3000    # Uses .env.local on port 3000

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default parameters
ENV_FILE="${1:-.env.network}"
PORT="${2:-8080}"

echo -e "${BLUE}🌐 Starting Flutter Web Network Development...${NC}"
echo -e "${BLUE}📄 Using environment file: ${ENV_FILE}${NC}"
echo -e "${BLUE}🔌 Port: ${PORT}${NC}"

# Check if specified env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file '$ENV_FILE' not found!${NC}"
    echo "Available environment files:"
    ls -la .env* 2>/dev/null || echo "No .env* files found"
    echo ""
    echo "Usage: $0 [env-file] [port]"
    echo "Examples:"
    echo "  $0                     # Uses .env.local on port 8080"
    echo "  $0 .env.dev            # Uses .env.dev on port 8080"
    echo "  $0 .env.local 3000     # Uses .env.local on port 3000"
    exit 1
fi

# Load environment variables from specified file
echo -e "${GREEN}✅ Loading environment from: ${ENV_FILE}${NC}"
source "$ENV_FILE"

# Get local IP address
echo -e "${BLUE}🔍 Detecting local IP address...${NC}"
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

if [ -z "$LOCAL_IP" ]; then
    echo -e "${RED}❌ Could not detect local IP address!${NC}"
    echo "Please check your network connection"
    exit 1
fi

echo -e "${GREEN}✅ Local IP detected: ${LOCAL_IP}${NC}"

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

# Display network access info
echo -e "${GREEN}🎉 Starting Flutter Web Server on Network!${NC}"
echo -e ""
echo -e "${YELLOW}📱 Access from your mobile device:${NC}"
echo -e "  🌐 Open browser on your phone and go to:"
echo -e "      ${GREEN}http://${LOCAL_IP}:${PORT}${NC}"
echo -e ""
echo -e "${YELLOW}💻 Access from other computers on same network:${NC}"
echo -e "  🌐 Use: ${GREEN}http://${LOCAL_IP}:${PORT}${NC}"
echo -e ""
echo -e "${YELLOW}📋 Make sure:${NC}"
echo -e "  • Your phone/device is on the same WiFi network"
echo -e "  • Firewall allows connections on port ${PORT}"
echo -e "  • Your router allows local network communication"
echo -e ""
echo -e "${BLUE}🔥 Hot reload: ${GREEN}ENABLED${NC}"
echo -e ""
echo -e "${YELLOW}💬 Flutter Commands (once running):${NC}"
echo -e "  ${GREEN}r${NC} - Hot reload (apply changes instantly)"
echo -e "  ${GREEN}R${NC} - Hot restart (restart the app completely)"
echo -e "  ${GREEN}q${NC} - Quit development server"
echo -e "  ${GREEN}h${NC} - Show help"
echo -e "  ${GREEN}c${NC} - Clear console"
echo -e ""
echo -e "${BLUE}🔧 DeviceKeyboardHandler Testing (Android):${NC}"
echo -e "  • Open Generate Study page on your Android device"
echo -e "  • Test keyboard behavior and input fields"
echo -e "  • Check browser console for device detection logs"
echo -e ""

# Run Flutter web server with network access
echo -e "${BLUE}🔧 Starting Flutter web server...${NC}"
echo -e "${YELLOW}🔍 Environment Variables:${NC}"
echo -e "  SUPABASE_URL: ${SUPABASE_URL}"
echo -e "  SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..." # Show only first 20 chars for security
echo -e "  GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}"
echo -e "  APP_URL: http://${LOCAL_IP}:${PORT}"
echo -e "  FLUTTER_ENV: ${FLUTTER_ENV}"
echo -e ""

flutter run -d web-server \
  --web-hostname=0.0.0.0 \
  --web-port=${PORT} \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=APP_URL="http://${LOCAL_IP}:${PORT}" \
  --dart-define=FLUTTER_ENV="$FLUTTER_ENV"

echo -e "${GREEN}✅ Flutter web network development session ended${NC}"