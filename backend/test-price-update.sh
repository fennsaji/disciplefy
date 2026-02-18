#!/bin/bash

# ============================================================================
# Subscription Price Update - Edge Function Test Script
# ============================================================================
# Tests the admin-update-subscription-price Edge Function
# Usage: ./test-price-update.sh

set -e

echo "=================================================="
echo "Subscription Price Update - Test Script"
echo "=================================================="
echo ""

# ============================================================================
# Configuration
# ============================================================================

# Get these from your Supabase dashboard or .env.local
SUPABASE_URL="${SUPABASE_URL:-http://localhost:54321}"
EDGE_FUNCTION_URL="${SUPABASE_URL}/functions/v1/admin-update-subscription-price"

# You need to provide these
JWT_TOKEN="${JWT_TOKEN:-}"
PLAN_PROVIDER_ID="${PLAN_PROVIDER_ID:-}"

# ============================================================================
# Validation
# ============================================================================

if [ -z "$JWT_TOKEN" ]; then
  echo "❌ Error: JWT_TOKEN not set"
  echo ""
  echo "Get your JWT token by:"
  echo "  1. Login to admin panel"
  echo "  2. Open DevTools → Application → Local Storage"
  echo "  3. Find 'sb-{project}-auth-token'"
  echo "  4. Copy the 'access_token' value"
  echo ""
  echo "Then run:"
  echo "  export JWT_TOKEN='your-jwt-token-here'"
  echo "  ./test-price-update.sh"
  exit 1
fi

if [ -z "$PLAN_PROVIDER_ID" ]; then
  echo "⚠️  Warning: PLAN_PROVIDER_ID not set, using example ID"
  echo ""
  echo "Get your plan_provider_id by running this SQL:"
  echo "  SELECT id FROM subscription_plan_providers"
  echo "  WHERE provider = 'razorpay' LIMIT 1;"
  echo ""
  echo "Then run:"
  echo "  export PLAN_PROVIDER_ID='your-uuid-here'"
  echo "  ./test-price-update.sh"
  echo ""
  read -p "Press Enter to continue with test data, or Ctrl+C to exit..."
  PLAN_PROVIDER_ID="00000000-0000-0000-0000-000000000000"
fi

# ============================================================================
# Test 1: Razorpay Price Update
# ============================================================================

echo ""
echo "Test 1: Razorpay Price Update"
echo "------------------------------"
echo "URL: $EDGE_FUNCTION_URL"
echo "Plan Provider ID: $PLAN_PROVIDER_ID"
echo ""

NEW_PRICE=14900  # ₹149

REQUEST_BODY=$(cat <<EOF
{
  "plan_provider_id": "$PLAN_PROVIDER_ID",
  "new_price_minor": $NEW_PRICE,
  "notes": "Test price update from script"
}
EOF
)

echo "Request:"
echo "$REQUEST_BODY" | jq '.'
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "$EDGE_FUNCTION_URL" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

echo "Response (HTTP $HTTP_CODE):"
echo "$RESPONSE_BODY" | jq '.'
echo ""

if [ "$HTTP_CODE" -eq 200 ]; then
  echo "✅ Test 1: PASSED"

  # Extract and display key info
  SUCCESS=$(echo "$RESPONSE_BODY" | jq -r '.success')
  if [ "$SUCCESS" = "true" ]; then
    OLD_PRICE=$(echo "$RESPONSE_BODY" | jq -r '.old_price_minor')
    NEW_PRICE_ACTUAL=$(echo "$RESPONSE_BODY" | jq -r '.new_price_minor')
    NEW_PLAN_ID=$(echo "$RESPONSE_BODY" | jq -r '.new_provider_plan_id')

    echo ""
    echo "📊 Price Update Summary:"
    echo "  Old Price: ₹$((OLD_PRICE / 100))"
    echo "  New Price: ₹$((NEW_PRICE_ACTUAL / 100))"
    echo "  Change: ₹$(((NEW_PRICE_ACTUAL - OLD_PRICE) / 100))"
    echo "  New Razorpay Plan ID: $NEW_PLAN_ID"
  fi
else
  echo "❌ Test 1: FAILED (HTTP $HTTP_CODE)"

  ERROR=$(echo "$RESPONSE_BODY" | jq -r '.error // "Unknown error"')
  echo "Error: $ERROR"
fi

# ============================================================================
# Test 2: Invalid Price (Too Low)
# ============================================================================

echo ""
echo "=================================================="
echo "Test 2: Invalid Price - Too Low"
echo "------------------------------"
echo ""

REQUEST_BODY_INVALID=$(cat <<EOF
{
  "plan_provider_id": "$PLAN_PROVIDER_ID",
  "new_price_minor": 50,
  "notes": "Test invalid price"
}
EOF
)

echo "Request (should fail):"
echo "$REQUEST_BODY_INVALID" | jq '.'
echo ""

RESPONSE_INVALID=$(curl -s -w "\n%{http_code}" \
  -X POST "$EDGE_FUNCTION_URL" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY_INVALID")

HTTP_CODE_INVALID=$(echo "$RESPONSE_INVALID" | tail -n1)
RESPONSE_BODY_INVALID=$(echo "$RESPONSE_INVALID" | sed '$d')

echo "Response (HTTP $HTTP_CODE_INVALID):"
echo "$RESPONSE_BODY_INVALID" | jq '.'
echo ""

if [ "$HTTP_CODE_INVALID" -eq 400 ]; then
  echo "✅ Test 2: PASSED (Correctly rejected invalid price)"
else
  echo "❌ Test 2: FAILED (Should have returned 400 Bad Request)"
fi

# ============================================================================
# Test 3: Same Price (No Change)
# ============================================================================

echo ""
echo "=================================================="
echo "Test 3: Same Price - No Change"
echo "------------------------------"
echo ""

# Get current price first
CURRENT_PRICE_RESPONSE=$(curl -s \
  "$SUPABASE_URL/rest/v1/subscription_plan_providers?id=eq.$PLAN_PROVIDER_ID&select=base_price_minor" \
  -H "apikey: ${SUPABASE_ANON_KEY:-your-anon-key}" \
  -H "Authorization: Bearer $JWT_TOKEN")

CURRENT_PRICE=$(echo "$CURRENT_PRICE_RESPONSE" | jq -r '.[0].base_price_minor // 0')

if [ "$CURRENT_PRICE" -eq 0 ]; then
  echo "⚠️  Could not fetch current price, skipping test"
else
  REQUEST_BODY_SAME=$(cat <<EOF
{
  "plan_provider_id": "$PLAN_PROVIDER_ID",
  "new_price_minor": $CURRENT_PRICE,
  "notes": "Test same price"
}
EOF
)

  echo "Request (same as current price):"
  echo "$REQUEST_BODY_SAME" | jq '.'
  echo ""

  RESPONSE_SAME=$(curl -s -w "\n%{http_code}" \
    -X POST "$EDGE_FUNCTION_URL" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY_SAME")

  HTTP_CODE_SAME=$(echo "$RESPONSE_SAME" | tail -n1)
  RESPONSE_BODY_SAME=$(echo "$RESPONSE_SAME" | sed '$d')

  echo "Response (HTTP $HTTP_CODE_SAME):"
  echo "$RESPONSE_BODY_SAME" | jq '.'
  echo ""

  if [ "$HTTP_CODE_SAME" -eq 400 ]; then
    echo "✅ Test 3: PASSED (Correctly rejected same price)"
  else
    echo "❌ Test 3: FAILED (Should have returned 400 Bad Request)"
  fi
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=================================================="
echo "Test Summary"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Check Supabase dashboard for new Razorpay plan"
echo "  2. Verify audit log entry in database"
echo "  3. Test in Admin UI at http://localhost:3000"
echo ""
echo "Useful SQL queries:"
echo "  -- View recent price changes"
echo "  SELECT * FROM admin_price_change_history LIMIT 5;"
echo ""
echo "  -- Check updated price"
echo "  SELECT base_price_minor, provider_plan_id, updated_at"
echo "  FROM subscription_plan_providers"
echo "  WHERE id = '$PLAN_PROVIDER_ID';"
echo ""
