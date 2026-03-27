#!/bin/bash

# IAP Local Test Server
#
# Single command to run the full local Google Play / Apple IAP test environment:
#   1. Starts Supabase services
#   2. Loads IAP credentials from your env file (env-first, DB-fallback)
#   3. Starts an ngrok tunnel and prints the Play Console webhook URL
#   4. Pauses so you can paste the URL into Play Console
#   5. Starts edge functions and begins receiving webhook events
#
# Usage:
#   ./run_iap_local_server.sh              # uses .env.iap (create this once)
#   ./run_iap_local_server.sh .env.android # use any other env file
#
# Options:
#   --reset      Reset database (WARNING: destroys all data)
#   --restart    Stop, restart, and apply pending migrations
#   --no-ngrok   Skip ngrok (webhook events from Play Console won't arrive)
#   --no-pause   Skip the "Press Enter" prompt before starting edge functions (CI use)
#   --help       Show this help
#
# ── One-time setup ────────────────────────────────────────────────────────────
# Create backend/.env.iap with:
#
#   # Copied from your .env.android / .env.local:
#   SUPABASE_URL=http://127.0.0.1:54321
#   SUPABASE_ANON_KEY=<anon key from supabase status>
#   GOOGLE_OAUTH_CLIENT_ID=...
#   GOOGLE_OAUTH_CLIENT_SECRET=...
#   OPENAI_API_KEY=...
#   ANTHROPIC_API_KEY=...
#   FIREBASE_PROJECT_ID=...
#   FIREBASE_PRIVATE_KEY=...
#   FIREBASE_CLIENT_EMAIL=...
#
#   # IAP mode
#   APP_ENVIRONMENT=sandbox
#   USE_MOCK=false
#
#   # Google Play service account (download JSON key from Google Cloud Console)
#   GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
#   GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_KEY_FILE=/path/to/sandbox-service-account.json
#   GOOGLE_PLAY_SANDBOX_PACKAGE_NAME=com.disciplefy.bible_study
#
# Then run once:
#   cd backend && sh scripts/run_iap_local_server.sh
#
# ── Manual step (shown at startup) ───────────────────────────────────────────
# After startup the script prints an ngrok URL and pauses.
# Paste that URL into Play Console → Monetize → Real-time developer notifications.
# Press Enter and the edge functions server starts.

set -e

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$BACKEND_ROOT"
pushd supabase > /dev/null

CONFIG_TOML="$BACKEND_ROOT/supabase/config.toml"
CONFIG_BACKUP="$BACKEND_ROOT/supabase/config.toml.backup"
CONFIG_TMP="$BACKEND_ROOT/supabase/config.toml.tmp"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── State ─────────────────────────────────────────────────────────────────────
NGROK_PID=""
NGROK_URL=""
MERGED_ENV_FILE=""

# ── Cleanup ───────────────────────────────────────────────────────────────────
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    if [ -f "$CONFIG_BACKUP" ]; then
        mv "$CONFIG_BACKUP" "$CONFIG_TOML"
        echo -e "${GREEN}✅ Restored original config.toml${NC}"
    fi
    rm -f "$CONFIG_TMP"
    [ -n "$MERGED_ENV_FILE" ] && rm -f "$MERGED_ENV_FILE"
    if [ -n "$NGROK_PID" ] && kill -0 "$NGROK_PID" 2>/dev/null; then
        kill "$NGROK_PID" 2>/dev/null || true
        echo -e "${GREEN}✅ Stopped ngrok${NC}"
    fi
    echo -e "${GREEN}✅ Done${NC}"
}
trap cleanup EXIT

# ── Help ──────────────────────────────────────────────────────────────────────
show_usage() {
    echo -e "${BLUE}IAP Local Test Server — single-command local billing setup${NC}"
    echo ""
    echo -e "Usage: $0 [options] [env-file]"
    echo -e "       $0              # default: .env.iap"
    echo ""
    echo "Options:"
    echo "  --reset      Reset database (WARNING: destroys all data)"
    echo "  --restart    Stop, restart, apply pending migrations"
    echo "  --no-ngrok   Skip ngrok webhook tunnel"
    echo "  --no-pause   Skip 'Press Enter' prompt (for CI / automated use)"
    echo "  --help       Show this help"
    echo ""
    echo -e "${BLUE}One-time setup: create backend/.env.iap${NC}"
    echo ""
    echo "  # Supabase / auth"
    echo "  SUPABASE_URL=http://127.0.0.1:54321"
    echo "  SUPABASE_ANON_KEY=<from supabase status>"
    echo "  GOOGLE_OAUTH_CLIENT_ID=..."
    echo "  GOOGLE_OAUTH_CLIENT_SECRET=..."
    echo ""
    echo "  # IAP mode"
    echo "  APP_ENVIRONMENT=sandbox   # or 'production'"
    echo "  USE_MOCK=false            # set true for UI-only testing"
    echo ""
    echo "  # Google Play sandbox (internal test track)"
    echo "  GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_EMAIL=..."
    echo "  GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_KEY_FILE=/path/to/key.json"
    echo "  GOOGLE_PLAY_SANDBOX_PACKAGE_NAME=com.disciplefy.bible_study"
    echo ""
    echo "  # Apple sandbox (optional)"
    echo "  APPLE_SANDBOX_SHARED_SECRET=..."
    echo "  APPLE_SANDBOX_BUNDLE_ID=com.disciplefy.bible_study"
    echo ""
    echo -e "${BLUE}Credential priority:${NC}"
    echo "  1. USE_MOCK=true  → purchases auto-succeed (no credentials needed)"
    echo "  2. Env vars above → used by edge functions directly"
    echo "  3. DB iap_config  → rows where is_active=true (production fallback)"
    echo ""
    echo -e "${BLUE}ngrok:${NC} Install with  brew install ngrok"
    echo "  Free tier gives a random HTTPS URL per session."
    echo "  Paid tier gives a stable domain (no need to update Play Console each run)."
}

# ── Arg parsing ───────────────────────────────────────────────────────────────
RESET_DB=false
RESTART_SERVICES=false
NO_NGROK=false
NO_PAUSE=false
ENV_FILE_PARAM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --reset)     RESET_DB=true;         shift ;;
        --restart)   RESTART_SERVICES=true; shift ;;
        --no-ngrok)  NO_NGROK=true;         shift ;;
        --no-pause)  NO_PAUSE=true;         shift ;;
        --help)      show_usage; exit 0 ;;
        -*)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_usage; exit 1 ;;
        *)  ENV_FILE_PARAM="$1"; shift ;;
    esac
done

# Default env file is .env.iap — a dedicated file for IAP testing
[[ -z "$ENV_FILE_PARAM" ]] && ENV_FILE_PARAM=".env.iap"

if [[ "$ENV_FILE_PARAM" = /* ]]; then
    ENV_FILE="$ENV_FILE_PARAM"
else
    ENV_FILE="$BACKEND_ROOT/$ENV_FILE_PARAM"
fi

echo -e "${BLUE}${BOLD}🪙 IAP Local Test Server${NC}"
echo -e "${BLUE}📄 Env file: ${ENV_FILE}${NC}"
echo ""

# ── Env file validation ───────────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Env file not found: ${ENV_FILE}${NC}"
    echo ""
    echo -e "Create ${CYAN}backend/.env.iap${NC} with your IAP credentials."
    echo -e "Run ${CYAN}$0 --help${NC} for the full template."
    echo ""
    echo "Available env files in backend/:"
    ls -1 "$BACKEND_ROOT"/.env* 2>/dev/null | sed 's|.*/||' || echo "  (none found)"
    exit 1
fi

if [ ! -f "$CONFIG_TOML" ]; then
    echo -e "${RED}❌ config.toml not found: $CONFIG_TOML${NC}"
    exit 1
fi

# ── Helper: read a var from env file (handles VAR=value with = in value) ──────
read_env() {
    grep "^${1}=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d'=' -f2- || true
}

# ── Load OAuth credentials ────────────────────────────────────────────────────
if grep -q "GOOGLE_OAUTH_CLIENT_ID" "$ENV_FILE" 2>/dev/null; then
    export GOOGLE_OAUTH_CLIENT_ID
    GOOGLE_OAUTH_CLIENT_ID=$(read_env GOOGLE_OAUTH_CLIENT_ID)
    export GOOGLE_OAUTH_CLIENT_SECRET
    GOOGLE_OAUTH_CLIENT_SECRET=$(read_env GOOGLE_OAUTH_CLIENT_SECRET)
fi

# ── Load mode flags ───────────────────────────────────────────────────────────
_RAW_APP_ENV=$(read_env APP_ENVIRONMENT)
_RAW_USE_MOCK=$(read_env USE_MOCK)
export APP_ENVIRONMENT="${_RAW_APP_ENV:-production}"
export USE_MOCK="${_RAW_USE_MOCK:-false}"

# ── Load Google Play IAP credentials ─────────────────────────────────────────
# Supports GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_KEY (inline JSON)
# or      GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_KEY_FILE (/path/to/key.json)
_load_gp_key() {
    local prefix="$1"
    local var="${prefix}_SERVICE_ACCOUNT_KEY"
    local file_var="${prefix}_SERVICE_ACCOUNT_KEY_FILE"

    local inline
    inline=$(read_env "$var")
    if [ -n "$inline" ]; then
        export "${var}=${inline}"
        return 0
    fi

    local key_file
    key_file=$(read_env "$file_var")
    if [ -n "$key_file" ]; then
        if [ -f "$key_file" ]; then
            local content
            content=$(cat "$key_file")
            export "${var}=${content}"
            return 0
        else
            echo -e "  ${RED}❌ Key file not found: ${key_file}${NC}"
            echo -e "     (set in ${file_var})"
        fi
    fi
    return 1
}

# Google Play sandbox
export GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_EMAIL
GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_EMAIL=$(read_env GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_EMAIL)
_GP_SB_PKG=$(read_env GOOGLE_PLAY_SANDBOX_PACKAGE_NAME)
export GOOGLE_PLAY_SANDBOX_PACKAGE_NAME="${_GP_SB_PKG:-com.disciplefy.bible_study}"
_load_gp_key "GOOGLE_PLAY_SANDBOX" 2>/dev/null || true

# Google Play production
export GOOGLE_PLAY_PRODUCTION_SERVICE_ACCOUNT_EMAIL
GOOGLE_PLAY_PRODUCTION_SERVICE_ACCOUNT_EMAIL=$(read_env GOOGLE_PLAY_PRODUCTION_SERVICE_ACCOUNT_EMAIL)
_GP_PR_PKG=$(read_env GOOGLE_PLAY_PRODUCTION_PACKAGE_NAME)
export GOOGLE_PLAY_PRODUCTION_PACKAGE_NAME="${_GP_PR_PKG:-com.disciplefy.bible_study}"
_load_gp_key "GOOGLE_PLAY_PRODUCTION" 2>/dev/null || true

# Apple
export APPLE_SANDBOX_SHARED_SECRET
APPLE_SANDBOX_SHARED_SECRET=$(read_env APPLE_SANDBOX_SHARED_SECRET)
_APPLE_SB_BUNDLE=$(read_env APPLE_SANDBOX_BUNDLE_ID)
export APPLE_SANDBOX_BUNDLE_ID="${_APPLE_SB_BUNDLE:-com.disciplefy.bible_study}"

export APPLE_PRODUCTION_SHARED_SECRET
APPLE_PRODUCTION_SHARED_SECRET=$(read_env APPLE_PRODUCTION_SHARED_SECRET)
_APPLE_PR_BUNDLE=$(read_env APPLE_PRODUCTION_BUNDLE_ID)
export APPLE_PRODUCTION_BUNDLE_ID="${_APPLE_PR_BUNDLE:-com.disciplefy.bible_study}"

# Other standard secrets (OPENAI, Firebase, etc.)
for _VAR in OPENAI_API_KEY ANTHROPIC_API_KEY FIREBASE_PROJECT_ID FIREBASE_PRIVATE_KEY FIREBASE_CLIENT_EMAIL; do
    _VAL=$(read_env "$_VAR")
    [ -n "$_VAL" ] && export "${_VAR}=${_VAL}"
done

# ── Supabase startup ──────────────────────────────────────────────────────────
if [ "$RESET_DB" = true ]; then
    echo -e "${YELLOW}⚠️  Database reset requested — stopping services...${NC}"
    supabase stop 2>/dev/null || true
elif [ "$RESTART_SERVICES" = true ]; then
    echo -e "${BLUE}🔄 Restart requested — stopping existing services...${NC}"
    supabase stop 2>/dev/null || true
else
    echo -e "${GREEN}⚡ Quick start — will use existing services if running...${NC}"
fi

# Apply localhost config.toml settings
cp "$CONFIG_TOML" "$CONFIG_BACKUP"
sed -i.tmp "s|site_url = \"http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:8080\"|site_url = \"http://localhost:59641\"|g" "$CONFIG_TOML"
sed -i.tmp "s|\"http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:8080\"|\"http://localhost:59641\"|g" "$CONFIG_TOML"
sed -i.tmp "s|redirect_uri = \"http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:54321/auth/v1/callback\"|redirect_uri = \"http://127.0.0.1:54321/auth/v1/callback\"|g" "$CONFIG_TOML"

if [ "$RESET_DB" = true ]; then
    echo -e "${YELLOW}🚀 Starting Supabase with database reset...${NC}"
    echo -e "${RED}⚠️  All existing data will be destroyed!${NC}"
    supabase start || { echo -e "${RED}❌ Failed to start Supabase${NC}"; exit 1; }
    supabase db reset || { echo -e "${RED}❌ Failed to reset database${NC}"; exit 1; }
else
    echo -e "${BLUE}🚀 Starting Supabase...${NC}"
    supabase start || { echo -e "${RED}❌ Failed to start Supabase${NC}"; exit 1; }
    if [ "$RESTART_SERVICES" = true ]; then
        echo -e "${BLUE}📦 Applying pending migrations...${NC}"
        supabase migration up && echo -e "${GREEN}✅ Migrations applied${NC}" || true
    fi
fi

sleep 3
supabase status

# ── ngrok webhook tunnel ──────────────────────────────────────────────────────
WEBHOOK_URL=""

if [ "$NO_NGROK" = false ]; then
    if ! command -v ngrok &>/dev/null; then
        echo -e ""
        echo -e "${YELLOW}⚠️  ngrok not installed — webhook events from Play Console won't arrive.${NC}"
        echo -e "   Install: ${CYAN}brew install ngrok${NC}"
        echo -e "   Or pass ${CYAN}--no-ngrok${NC} to suppress this warning."
    else
        echo -e ""
        _NGROK_DOMAIN=$(read_env NGROK_DOMAIN)
        if [ -n "$_NGROK_DOMAIN" ]; then
            echo -e "${BLUE}🔗 Starting ngrok tunnel (static domain: ${_NGROK_DOMAIN}) → http://127.0.0.1:54321${NC}"
            pkill -f "ngrok http" 2>/dev/null || true
            sleep 1
            ngrok http --domain="$_NGROK_DOMAIN" 54321 --log=stdout > /tmp/ngrok_iap.log 2>&1 &
        else
            echo -e "${BLUE}🔗 Starting ngrok tunnel → http://127.0.0.1:54321${NC}"
            pkill -f "ngrok http 54321" 2>/dev/null || true
            sleep 1
            ngrok http 54321 --log=stdout > /tmp/ngrok_iap.log 2>&1 &
        fi
        NGROK_PID=$!

        echo -e "${BLUE}⏳ Waiting for ngrok...${NC}"
        for i in $(seq 1 20); do
            NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | \
                python3 -c "
import sys, json
try:
    tunnels = json.load(sys.stdin).get('tunnels', [])
    url = next((t['public_url'] for t in tunnels if t['public_url'].startswith('https')), '')
    print(url)
except:
    print('')
" 2>/dev/null || true)
            [ -n "$NGROK_URL" ] && break
            sleep 1
        done

        if [ -n "$NGROK_URL" ]; then
            WEBHOOK_URL="${NGROK_URL}/functions/v1/google-play-webhook"
            echo -e "${GREEN}✅ ngrok active: ${NGROK_URL}${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not get ngrok URL — check /tmp/ngrok_iap.log${NC}"
        fi
    fi
fi

# ── IAP credential status ─────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}${BOLD}  IAP Credential Status${NC}"
echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  App environment : ${CYAN}${APP_ENVIRONMENT}${NC}"
echo -e "  Mock mode       : ${USE_MOCK}"
echo ""

if [ "$USE_MOCK" = "true" ]; then
    echo -e "  ${YELLOW}🎭 MOCK MODE — all purchases auto-succeed, no credentials needed${NC}"
else
    # Google Play sandbox
    if [ -n "$GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_EMAIL" ] && \
       [ -n "$GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_KEY" ]; then
        _short="${GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_EMAIL:0:40}"
        echo -e "  ${GREEN}✅ Google Play [sandbox]${NC}"
        echo -e "      source  : ENV_VARS"
        echo -e "      email   : ${_short}"
        echo -e "      package : ${GOOGLE_PLAY_SANDBOX_PACKAGE_NAME}"
    else
        echo -e "  ${YELLOW}⚠️  Google Play [sandbox]  NOT CONFIGURED${NC}"
        [ -z "$GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_EMAIL" ] && \
            echo -e "      missing : GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_EMAIL"
        [ -z "$GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_KEY" ] && \
            echo -e "      missing : GOOGLE_PLAY_SANDBOX_SERVICE_ACCOUNT_KEY or _KEY_FILE"
        echo -e "      fallback: DB iap_config (is_active=true rows)"
    fi
    echo ""

    # Google Play production
    if [ -n "$GOOGLE_PLAY_PRODUCTION_SERVICE_ACCOUNT_EMAIL" ] && \
       [ -n "$GOOGLE_PLAY_PRODUCTION_SERVICE_ACCOUNT_KEY" ]; then
        echo -e "  ${GREEN}✅ Google Play [production] — ENV_VARS${NC}"
    else
        echo -e "  ${BLUE}ℹ️  Google Play [production] — not in env file (DB fallback)${NC}"
    fi
    echo ""

    # Apple
    if [ -n "$APPLE_SANDBOX_SHARED_SECRET" ]; then
        echo -e "  ${GREEN}✅ Apple [sandbox]${NC}"
        echo -e "      source  : ENV_VARS  |  bundle: ${APPLE_SANDBOX_BUNDLE_ID}"
    else
        echo -e "  ${BLUE}ℹ️  Apple [sandbox] — not configured${NC}"
    fi
fi

echo ""
echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ── Manual steps banner (shown before blocking functions serve call) ───────────
if [ -n "$WEBHOOK_URL" ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}${BOLD}│  MANUAL STEP — required for real purchase testing   │${NC}"
    echo -e "${YELLOW}${BOLD}└─────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  Set this webhook URL in Play Console:"
    echo ""
    echo -e "  ${GREEN}${BOLD}${WEBHOOK_URL}${NC}"
    echo ""
    echo -e "  How:"
    echo -e "    1. Play Console → your app → Monetize"
    echo -e "    2. Real-time developer notifications → Edit"
    echo -e "    3. Paste URL above → Save"
    echo -e "    4. Play Console sends a test ping — watch logs below to confirm"
    echo ""
    echo -e "  ${CYAN}Note: URL changes every session unless NGROK_DOMAIN is set in .env.iap.${NC}"
    echo -e "  ${CYAN}      Free static domain: ngrok dashboard → Cloud Edge → Domains.${NC}"
    echo ""

    if [ "$NO_PAUSE" = false ]; then
        echo -e "${BOLD}Press Enter after updating Play Console to start edge functions...${NC}"
        read -r
    fi
elif [ "$NO_NGROK" = false ] && command -v ngrok &>/dev/null; then
    # ngrok was attempted but URL unavailable
    echo ""
    echo -e "${YELLOW}⚠️  ngrok URL unavailable — starting edge functions without webhook tunnel${NC}"
    echo -e "   Check /tmp/ngrok_iap.log for errors"
    echo ""
fi

# ── Build merged env file ─────────────────────────────────────────────────────
# supabase functions serve --env-file reads the file literally, so
# GOOGLE_PLAY_*_KEY_FILE references are NOT expanded for Deno.
# We build a temp env file with the actual key JSON inlined as _KEY.
MERGED_ENV_FILE="/tmp/supabase_iap_merged_$$.env"
cp "$ENV_FILE" "$MERGED_ENV_FILE"

_inline_key_file() {
    local prefix="$1"
    local key_var="${prefix}_SERVICE_ACCOUNT_KEY"
    local b64_var="${prefix}_SERVICE_ACCOUNT_KEY_B64"
    local file_var="${prefix}_SERVICE_ACCOUNT_KEY_FILE"

    # Skip if inline key or b64 already present in env file
    if grep -q "^${key_var}=\|^${b64_var}=" "$ENV_FILE" 2>/dev/null; then
        return
    fi

    local key_file
    key_file=$(grep "^${file_var}=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d'=' -f2-)
    if [ -n "$key_file" ] && [ -f "$key_file" ]; then
        # Base64-encode the JSON — avoids env file parsing issues caused by
        # slashes, quotes, and newlines inside the private key value.
        local b64
        b64=$(python3 -c "
import json, sys, base64
raw = json.load(open(sys.argv[1]))
print(base64.b64encode(json.dumps(raw).encode()).decode())
" "$key_file" 2>/dev/null)
        if [ -n "$b64" ]; then
            echo "${b64_var}=${b64}" >> "$MERGED_ENV_FILE"
            echo -e "${GREEN}✅ Inlined ${prefix} key (base64) into merged env${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not parse ${key_file} as JSON${NC}"
        fi
    fi
}

_inline_key_file "GOOGLE_PLAY_SANDBOX"
_inline_key_file "GOOGLE_PLAY_PRODUCTION"

# Ensure APP_ENVIRONMENT is in the merged file (may have been set as default)
if ! grep -q "^APP_ENVIRONMENT=" "$MERGED_ENV_FILE" 2>/dev/null; then
    echo "APP_ENVIRONMENT=${APP_ENVIRONMENT}" >> "$MERGED_ENV_FILE"
fi

# ── Start edge functions (blocking) ───────────────────────────────────────────
popd > /dev/null
echo -e "${BLUE}🔧 Starting Edge Functions — logs below:${NC}"
echo ""
supabase functions serve --env-file "$MERGED_ENV_FILE"
