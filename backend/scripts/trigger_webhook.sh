#!/bin/bash
# Simulate a Razorpay subscription webhook event for local testing.
#
# Usage (non-interactive):
#   ./scripts/trigger_webhook.sh sub_XXX subscription.activated
#
# Usage (interactive - pick sub + event from menu):
#   ./scripts/trigger_webhook.sh

SUPABASE_URL="http://127.0.0.1:54321"
ENDPOINT="$SUPABASE_URL/functions/v1/dev-trigger-webhook"
DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

EVENTS=(
  "subscription.authenticated"
  "subscription.activated"
  "subscription.charged"
  "subscription.cancelled"
  "subscription.completed"
  "subscription.paused"
  "subscription.resumed"
)

# ── Helper: fire the webhook ───────────────────────────────────────────────────
fire() {
  local sub_id="$1"
  local event="$2"

  echo ""
  echo "→ Triggering '$event' for $sub_id ..."
  echo ""

  local body
  body=$(curl -s -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{\"provider_subscription_id\":\"$sub_id\",\"event\":\"$event\"}")

  if command -v python3 &>/dev/null; then
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
  else
    echo "$body"
  fi

  echo ""
  if echo "$body" | grep -q '"success":true'; then
    echo "✅ Done"
  else
    echo "❌ Failed"
    exit 1
  fi
}

# ── Non-interactive mode ───────────────────────────────────────────────────────
if [[ -n "$1" && -n "$2" ]]; then
  fire "$1" "$2"
  exit 0
fi

# ── Interactive mode ───────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════╗"
echo "║      Dev Webhook Trigger (local only)        ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Fetch recent active subscriptions from DB
SUBS=$(psql "$DB_URL" -t -A -F '|' \
  -c "SELECT provider_subscription_id, plan_type, status, user_id FROM subscriptions WHERE provider_subscription_id NOT LIKE 'trial%' AND provider_subscription_id NOT LIKE 'admin%' ORDER BY created_at DESC LIMIT 10;" 2>/dev/null)

if [[ -z "$SUBS" ]]; then
  echo "No subscriptions found in local DB."
  echo "Subscribe to a plan first, then re-run this script."
  exit 1
fi

# Show subscription menu
echo "Select a subscription:"
echo ""
declare -a SUB_IDS
i=1
while IFS='|' read -r sub_id plan_type status user_id; do
  echo "  $i) $sub_id  [$plan_type / $status]"
  SUB_IDS[$i]="$sub_id"
  ((i++))
done <<< "$SUBS"

echo ""
read -rp "Enter number: " sub_choice

SUB_ID="${SUB_IDS[$sub_choice]}"
if [[ -z "$SUB_ID" ]]; then
  echo "Invalid selection."
  exit 1
fi

echo ""
echo "Selected: $SUB_ID"
echo ""

# Show event menu
echo "Select an event:"
echo ""
for j in "${!EVENTS[@]}"; do
  echo "  $((j+1))) ${EVENTS[$j]}"
done

echo ""
read -rp "Enter number: " event_choice

EVENT="${EVENTS[$((event_choice-1))]}"
if [[ -z "$EVENT" ]]; then
  echo "Invalid selection."
  exit 1
fi

fire "$SUB_ID" "$EVENT"
