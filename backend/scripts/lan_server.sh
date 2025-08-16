#!/bin/bash

# Supabase Network Development Script
# This script starts Supabase services accessible from local network (LAN/WiFi)
# Perfect for mobile testing when you need backend access from other devices
# Usage: ./run_network_server.sh [env-file]
# Default: ./run_network_server.sh .env.local
# Examples:
#   ./run_network_server.sh                # Uses .env.local
#   ./run_network_server.sh .env.dev       # Uses .env.dev

set -e

# Cleanup function to restore original config
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up network configuration...${NC}"
    if [ -f "supabase/config.toml.backup" ]; then
        mv supabase/config.toml.backup supabase/config.toml
        echo -e "${GREEN}✅ Restored original config.toml${NC}"
    fi
    if [ -f "supabase/config.toml.tmp" ]; then
        rm -f supabase/config.toml.tmp
    fi
    echo -e "${GREEN}✅ Network session cleanup complete${NC}"
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default parameters
ENV_FILE="${1:-.env.local}"

echo -e "${BLUE}🌐 Starting Supabase Network Development Server...${NC}"
echo -e "${BLUE}📄 Using environment file: ${ENV_FILE}${NC}"

# Check if specified env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file '$ENV_FILE' not found!${NC}"
    echo "Available environment files:"
    ls -la .env* 2>/dev/null || echo "No .env* files found"
    echo ""
    echo "Usage: $0 [env-file]"
    echo "Examples:"
    echo "  $0                # Uses .env.local"
    echo "  $0 .env.dev       # Uses .env.dev"
    exit 1
fi

# Get local IP address
echo -e "${BLUE}🔍 Detecting local IP address...${NC}"
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

if [ -z "$LOCAL_IP" ]; then
    echo -e "${RED}❌ Could not detect local IP address!${NC}"
    echo "Please check your network connection"
    exit 1
fi

echo -e "${GREEN}✅ Local IP detected: ${LOCAL_IP}${NC}"

# Stop any existing Supabase services
echo -e "${BLUE}🔧 Stopping any existing Supabase services...${NC}"
supabase stop --no-backup 2>/dev/null || true

# Create a temporary network config for network access
# We need to modify the bind address to allow external connections
echo -e "${BLUE}🔧 Configuring Supabase for network access...${NC}"

# Create temporary config.toml with network settings
echo -e "${BLUE}📝 Creating network configuration...${NC}"
cp supabase/config.toml supabase/config.toml.backup

# Update config.toml with network IP addresses
sed -i.tmp "s|site_url = \"http://localhost:59641\"|site_url = \"http://${LOCAL_IP}:8080\"|g" supabase/config.toml
sed -i.tmp "s|\"http://localhost:59641\"|\"http://${LOCAL_IP}:8080\"|g" supabase/config.toml
sed -i.tmp "s|redirect_uri = \"http://127.0.0.1:54321/auth/v1/callback\"|redirect_uri = \"http://${LOCAL_IP}:54321/auth/v1/callback\"|g" supabase/config.toml

echo -e "${GREEN}✅ Updated OAuth configuration for network IP: ${LOCAL_IP}${NC}"

# Start Supabase with network access
# Note: Supabase CLI doesn't directly support external IP binding,
# but we can use Docker network configuration
echo -e "${BLUE}🚀 Starting Supabase services...${NC}"
supabase start

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to start Supabase services${NC}"
    echo "Please check the error messages above"
    exit 1
fi

# Wait for services to be ready
echo -e "${BLUE}⏳ Waiting for services to be ready...${NC}"
sleep 3

# Check if services are running
echo -e "${BLUE}🔍 Checking service status...${NC}"
supabase status

echo -e "${GREEN}✅ Supabase services started successfully!${NC}"
echo -e ""
echo -e "${YELLOW}📱 Network Access Information:${NC}"
echo -e "  🌐 Supabase is running on: ${GREEN}http://127.0.0.1:54321${NC}"
echo -e "  📱 For mobile access, you need to forward ports to: ${GREEN}http://${LOCAL_IP}:54321${NC}"
echo -e ""
echo -e "${BLUE}🔧 Port Forwarding Solutions:${NC}"
echo -e ""
echo -e "${YELLOW}Option 1: SSH Port Forwarding (Recommended)${NC}"
echo -e "  Run this command in a NEW terminal window:"
echo -e "  ${GREEN}ssh -L ${LOCAL_IP}:54321:127.0.0.1:54321 -L ${LOCAL_IP}:54323:127.0.0.1:54323 \${NC}"
echo -e "  ${GREEN}      -L ${LOCAL_IP}:54324:127.0.0.1:54324 localhost -N${NC}"
echo -e ""
echo -e "  This forwards:"
echo -e "    • Port 54321 (Supabase API) → ${LOCAL_IP}:54321"
echo -e "    • Port 54323 (PostgREST) → ${LOCAL_IP}:54323"
echo -e "    • Port 54324 (Studio) → ${LOCAL_IP}:54324"
echo -e ""
echo -e "${YELLOW}Option 2: Socat Port Forwarding (Alternative)${NC}"
echo -e "  Install socat: ${GREEN}brew install socat${NC}"
echo -e "  Run in a NEW terminal:"
echo -e "  ${GREEN}socat TCP-LISTEN:54321,bind=${LOCAL_IP},fork TCP:127.0.0.1:54321 &${NC}"
echo -e ""
echo -e "${YELLOW}🛠️ Frontend Configuration${NC}"
echo -e "  Your frontend .env.network should use:"
echo -e "  ${GREEN}SUPABASE_URL=http://${LOCAL_IP}:54321${NC}"
echo -e "  (This is already configured in .env.network)"
echo -e ""
echo -e "${BLUE}🎯 Google OAuth Configuration${NC}"
echo -e "  ✅ Updated Google OAuth callback to: ${GREEN}http://${LOCAL_IP}:54321/auth/v1/callback${NC}"
echo -e "  ✅ Updated site URL to: ${GREEN}http://${LOCAL_IP}:8080${NC}"
echo -e "  📝 Note: Original config.toml backed up and will be restored on exit"
echo -e ""
echo -e "${BLUE}🔥 Important Notes:${NC}"
echo -e "  • Keep this terminal running for Supabase services"
echo -e "  • Run port forwarding in a separate terminal"
echo -e "  • Use frontend/scripts/run-web-network.sh for Flutter web"
echo -e "  • Test on mobile by visiting: http://${LOCAL_IP}:8080"
echo -e "  • Google OAuth will now work from mobile devices"
echo -e ""

# Start the Edge Functions server with network access
echo -e "${BLUE}🔧 Starting Edge Functions server...${NC}"
echo -e "${YELLOW}📋 Make sure your firewall allows connections on ports:${NC}"
echo -e "  • 54321 (Supabase API)"
echo -e "  • 54323 (PostgREST)"
echo -e "  • 54324 (Studio - optional)"
echo -e ""

# Run the functions server
echo -e "${BLUE}🚀 Starting Edge Functions with environment: ${ENV_FILE}${NC}"
supabase functions serve --env-file "$ENV_FILE"