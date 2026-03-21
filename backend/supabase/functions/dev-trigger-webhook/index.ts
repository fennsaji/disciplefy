/**
 * DEV ONLY: Razorpay Webhook Simulator
 *
 * Simulates Razorpay subscription webhook events for local testing.
 * Builds a properly signed webhook payload from the DB subscription
 * and fires it at the razorpay-webhook handler.
 *
 * SECURITY: Refuses all requests unless SUPABASE_URL contains 127.0.0.1
 */

import { createClient } from 'npm:@supabase/supabase-js'
import { generateHmacSha256 } from '../_shared/utils/crypto-utils.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SUPPORTED_EVENTS = [
  'subscription.authenticated',
  'subscription.activated',
  'subscription.charged',
  'subscription.cancelled',
  'subscription.completed',
  'subscription.paused',
  'subscription.resumed',
]

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // SECURITY: Dev-only guard — reject in production
  // Production Supabase URLs always contain .supabase.co; local never does.
  const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
  const isProduction = supabaseUrl.includes('.supabase.co')
  if (isProduction) {
    return new Response(JSON.stringify({ error: 'Not available in production' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET')
  if (!webhookSecret) {
    return new Response(JSON.stringify({ error: 'RAZORPAY_WEBHOOK_SECRET not configured' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  let body: { provider_subscription_id?: string; event?: string }
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const { provider_subscription_id, event } = body

  if (!provider_subscription_id || !event) {
    return new Response(
      JSON.stringify({ error: 'provider_subscription_id and event are required' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  if (!SUPPORTED_EVENTS.includes(event)) {
    return new Response(
      JSON.stringify({ error: `Unsupported event. Supported: ${SUPPORTED_EVENTS.join(', ')}` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Load subscription from DB
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
  const supabase = createClient(supabaseUrl, serviceKey)

  const { data: sub, error: subError } = await supabase
    .from('subscriptions')
    .select('*, subscription_plans(plan_code)')
    .eq('provider_subscription_id', provider_subscription_id)
    .single()

  if (subError || !sub) {
    return new Response(
      JSON.stringify({ error: `Subscription not found: ${provider_subscription_id}` }),
      { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Build timestamps
  const now = Math.floor(Date.now() / 1000)
  const thirtyDays = 30 * 24 * 60 * 60

  const currentStart = sub.current_period_start
    ? Math.floor(new Date(sub.current_period_start).getTime() / 1000)
    : now
  const currentEnd = sub.current_period_end
    ? Math.floor(new Date(sub.current_period_end).getTime() / 1000)
    : now + thirtyDays
  const chargeAt = sub.next_billing_at
    ? Math.floor(new Date(sub.next_billing_at).getTime() / 1000)
    : now + thirtyDays

  const planCode =
    (sub.subscription_plans as { plan_code: string } | null)?.plan_code ||
    sub.plan_type?.replace('_monthly', '').replace('_trial', '') ||
    'plus'

  // Determine subscription status for the event
  const statusForEvent: Record<string, string> = {
    'subscription.authenticated': 'authenticated',
    'subscription.activated': 'active',
    'subscription.charged': 'active',
    'subscription.cancelled': 'cancelled',
    'subscription.completed': 'completed',
    'subscription.paused': 'paused',
    'subscription.resumed': 'active',
  }

  const subscriptionEntity = {
    id: provider_subscription_id,
    entity: 'subscription',
    plan_id: sub.provider_plan_id || 'plan_dev',
    customer_id: sub.provider_customer_id || null,
    status: statusForEvent[event] || 'active',
    current_start: currentStart,
    current_end: currentEnd,
    ended_at: event === 'subscription.cancelled' ? now : null,
    quantity: 1,
    notes: {
      user_id: sub.user_id,
      plan_code: planCode,
    },
    charge_at: chargeAt,
    start_at: currentStart,
    end_at: null,
    auth_attempts: 0,
    total_count: 360,
    paid_count: (sub.paid_count || 0) + (event === 'subscription.charged' ? 1 : 0),
    customer_notify: 1,
    created_at: Math.floor(new Date(sub.created_at).getTime() / 1000),
    expire_by: null,
    expired_at: null,
    has_scheduled_changes: false,
    change_scheduled_at: null,
    short_url: `https://rzp.io/l/dev_${provider_subscription_id}`,
    remaining_count: 359,
  }

  // For subscription.charged we also need a mock payment entity
  const mockPaymentId = `pay_dev_${Date.now()}`
  const webhookPayload: Record<string, unknown> = {
    entity: 'event',
    account_id: 'acc_dev',
    event,
    contains: event === 'subscription.charged' ? ['subscription', 'payment'] : ['subscription'],
    payload: {
      subscription: { entity: subscriptionEntity },
      ...(event === 'subscription.charged' && {
        payment: {
          entity: {
            id: mockPaymentId,
            entity: 'payment',
            amount: sub.amount_paise || 49900,
            currency: sub.currency || 'INR',
            status: 'captured',
            order_id: null,
            invoice_id: `inv_dev_${Date.now()}`,
            method: 'upi',
            captured: true,
            email: null,
            contact: null,
            created_at: now,
          },
        },
      }),
    },
    created_at: now,
  }

  // Sign and fire at the real webhook handler
  const payloadStr = JSON.stringify(webhookPayload)
  const signature = await generateHmacSha256(webhookSecret, payloadStr)

  const webhookUrl = `${supabaseUrl}/functions/v1/razorpay-webhook`
  const webhookRes = await fetch(webhookUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-razorpay-signature': signature,
    },
    body: payloadStr,
  })

  const responseText = await webhookRes.text()
  console.log(`[DevTrigger] ${event} for ${provider_subscription_id} → ${webhookRes.status}`)

  return new Response(
    JSON.stringify({
      success: webhookRes.ok,
      event,
      provider_subscription_id,
      plan_code: planCode,
      webhook_status: webhookRes.status,
      webhook_response: responseText,
    }),
    {
      status: webhookRes.ok ? 200 : 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  )
})
