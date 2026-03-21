#!/bin/bash
# =====================================================
# ngrok tunnel — exposes local Supabase to Razorpay webhooks
# Static domain: unbevelled-jolie-skillful.ngrok-free.dev
#
# Usage: sh scripts/run_ngrok_tunnel.sh
#
# Set in Razorpay dashboard (Test mode) → Webhooks:
#   https://unbevelled-jolie-skillful.ngrok-free.dev/functions/v1/razorpay-webhook
# =====================================================

DOMAIN="unbevelled-jolie-skillful.ngrok-free.dev"
LOCAL_PORT=54321

echo ""
echo "🚇 Starting ngrok tunnel..."
echo "   Local:  http://localhost:$LOCAL_PORT"
echo "   Public: https://$DOMAIN"
echo ""
echo "📋 Razorpay webhook URL (set this once in dashboard):"
echo "   https://$DOMAIN/functions/v1/razorpay-webhook"
echo ""

ngrok http --url=$DOMAIN $LOCAL_PORT
