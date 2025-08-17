#!/bin/bash

# Supabase Local Development Script
# This script starts Supabase services for local development
# Perfect for localhost development with proper configuration management
# Usage: ./run_local_server.sh [env-file]
# Default: ./run_local_server.sh .env.local
# Examples:
#   ./run_local_server.sh                # Uses .env.local
#   ./run_local_server.sh .env.dev       # Uses .env.dev

set -e

# Determine script directory and backend root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to backend root directory to ensure all relative paths work
cd "$BACKEND_ROOT"

echo "🔧 Script directory: $SCRIPT_DIR"
echo "🔧 Backend root: $BACKEND_ROOT"
echo "🔧 Working directory: $(pwd)"

# Define absolute paths for config files
CONFIG_TOML="$BACKEND_ROOT/supabase/config.toml"
CONFIG_BACKUP="$BACKEND_ROOT/supabase/config.toml.backup"
CONFIG_TMP="$BACKEND_ROOT/supabase/config.toml.tmp"

# Cleanup function to restore original config if modified
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up local development configuration...${NC}"
    
    # Use absolute paths for cleanup to ensure it works from any directory
    if [ -f "$CONFIG_BACKUP" ]; then
        mv "$CONFIG_BACKUP" "$CONFIG_TOML"
        echo -e "${GREEN}✅ Restored original config.toml${NC}"
    fi
    if [ -f "$CONFIG_TMP" ]; then
        rm -f "$CONFIG_TMP"
    fi
    echo -e "${GREEN}✅ Local development cleanup complete${NC}"
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
# Handle environment file path - resolve relative to backend root
ENV_FILE_PARAM="${1:-.env.local}"
if [[ "$ENV_FILE_PARAM" = /* ]]; then
    # Absolute path - use as is
    ENV_FILE="$ENV_FILE_PARAM"
else
    # Relative path - resolve relative to backend root
    ENV_FILE="$BACKEND_ROOT/$ENV_FILE_PARAM"
fi

echo -e "${BLUE}🏠 Starting Supabase Local Development Server...${NC}"
echo -e "${BLUE}📄 Using environment file: ${ENV_FILE}${NC}"
echo -e "${BLUE}📄 Resolved config.toml path: ${CONFIG_TOML}${NC}"

# Check if specified env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file '$ENV_FILE' not found!${NC}"
    echo "Available environment files:"
    ls -la "$BACKEND_ROOT"/.env* 2>/dev/null || echo "No .env* files found"
    echo ""
    echo "Usage: $0 [env-file]"
    echo "Examples:"
    echo "  $0                # Uses .env.local"
    echo "  $0 .env.dev       # Uses .env.dev"
    exit 1
fi

# Verify config.toml exists
if [ ! -f "$CONFIG_TOML" ]; then
    echo -e "${RED}❌ Config file not found: $CONFIG_TOML${NC}"
    echo "Please ensure you're running this script from a Supabase project directory"
    exit 1
fi

# Stop any existing Supabase services
echo -e "${BLUE}🔧 Stopping any existing Supabase services...${NC}"
supabase stop --no-backup 2>/dev/null || true

# Check if config needs to be restored to localhost settings
# (in case lan_server.sh modified it and didn't restore properly)
echo -e "${BLUE}🔧 Ensuring localhost configuration...${NC}"

# Create backup of current config before any modifications
cp "$CONFIG_TOML" "$CONFIG_BACKUP"

# Ensure config.toml has localhost settings (restore from any network settings)
sed -i.tmp "s|site_url = \"http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:8080\"|site_url = \"http://localhost:59641\"|g" "$CONFIG_TOML"
sed -i.tmp "s|\"http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:8080\"|\"http://localhost:59641\"|g" "$CONFIG_TOML"
sed -i.tmp "s|redirect_uri = \"http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:54321/auth/v1/callback\"|redirect_uri = \"http://127.0.0.1:54321/auth/v1/callback\"|g" "$CONFIG_TOML"

echo -e "${GREEN}✅ Ensured localhost configuration${NC}"

# Start Supabase services
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
echo -e "${YELLOW}🏠 Local Development Information:${NC}"
echo -e "  🌐 Supabase API: ${GREEN}http://127.0.0.1:54321${NC}"
echo -e "  🎯 Supabase Studio: ${GREEN}http://127.0.0.1:54323${NC}"
echo -e "  🗄️ Database: ${GREEN}postgresql://postgres:postgres@127.0.0.1:54322/postgres${NC}"
echo -e ""
echo -e "${BLUE}🛠️ Frontend Configuration${NC}"
echo -e "  Your frontend should use these settings:"
echo -e "  ${GREEN}SUPABASE_URL=http://127.0.0.1:54321${NC}"
echo -e "  ${GREEN}SUPABASE_ANON_KEY=<anon_key_from_status>${NC}"
echo -e "  (These are already configured in .env.local)"
echo -e ""
echo -e "${BLUE}🎯 OAuth Configuration${NC}"
echo -e "  ✅ Google OAuth callback: ${GREEN}http://127.0.0.1:54321/auth/v1/callback${NC}"
echo -e "  ✅ Site URL: ${GREEN}http://localhost:59641${NC}"
echo -e "  📝 Note: Original config.toml backed up and will be restored on exit"
echo -e ""
echo -e "${BLUE}🔥 Important Notes:${NC}"
echo -e "  • This is for LOCAL development only"
echo -e "  • Use frontend/scripts/run_web_local.sh for Flutter web"
echo -e "  • Test locally by visiting: http://localhost:59641"
echo -e "  • Google OAuth will work from localhost"
echo -e "  • Database migrations and functions are available"
echo -e ""

# Start the Edge Functions server for local development
echo -e "${BLUE}🔧 Starting Edge Functions server for local development...${NC}"
echo -e "${YELLOW}📋 Available endpoints will be shown below:${NC}"
echo -e ""

# Run the functions server
echo -e "${BLUE}🚀 Starting Edge Functions with environment: ${ENV_FILE}${NC}"
supabase functions serve --env-file "$ENV_FILE"
