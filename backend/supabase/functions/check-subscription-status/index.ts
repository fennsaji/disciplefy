/**
 * Check Subscription Status Edge Function
 *
 * Cron job that runs daily at 2 AM UTC as a safety net for missed webhooks.
 * Performs three tasks:
 *   A) Expires overdue IAP subscriptions (google_play / apple_appstore) whose
 *      current_period_end has passed the 1-day grace buffer.
 *   B) Flags pending webhook events that were never processed after 10 minutes
 *      so they surface in monitoring dashboards.
 *   C) Expires subscriptions whose metadata-based grace period has lapsed.
 *
 * Schedule: "0 2 * * *" (2 AM UTC daily)
 * Security: Requires CRON_SECRET authorization header
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // Verify this is an authorized cron job request
    const authHeader = req.headers.get('Authorization')
    const cronSecret = Deno.env.get('CRON_SECRET')

    if (!authHeader || !cronSecret || authHeader !== `Bearer ${cronSecret}`) {
      console.error('[CheckSubscriptionStatus] Unauthorized request attempt')
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Unauthorized - Invalid or missing CRON_SECRET'
        }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client with service role key for admin operations
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    const startedAt = new Date().toISOString()
    console.log(`[CheckSubscriptionStatus] Starting daily check at ${startedAt}`)

    // -------------------------------------------------------------------------
    // Task A: Expire overdue IAP subscriptions
    // Find active/pending_cancellation subscriptions from google_play or
    // apple_appstore whose current_period_end is more than 1 day in the past.
    // 1-day buffer gives the webhook handler a chance to fire before we step in.
    // -------------------------------------------------------------------------

    const graceCutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()

    const { data: expiredSubscriptions, error: expireError } = await supabaseClient
      .from('subscriptions')
      .update({
        status: 'expired',
        updated_at: new Date().toISOString()
      })
      .in('status', ['active', 'pending_cancellation'])
      .not('current_period_end', 'is', null)
      .lt('current_period_end', graceCutoff)
      .in('provider', ['google_play', 'apple_appstore'])
      .select('id, user_id, provider, current_period_end, status')

    if (expireError) {
      console.error('[CheckSubscriptionStatus] Error expiring overdue subscriptions:', expireError)
    } else {
      const expiredCount = expiredSubscriptions?.length ?? 0
      console.log(`[CheckSubscriptionStatus] Task A: Expired ${expiredCount} overdue IAP subscription(s)`)
      if (expiredCount > 0) {
        console.log('[CheckSubscriptionStatus] Expired subscription IDs:', expiredSubscriptions?.map((s) => s.id))
      }
    }

    // -------------------------------------------------------------------------
    // Task B: Flag stale pending webhook events
    // Find iap_webhook_events rows that are still 'pending' with no processed_at
    // timestamp and were received more than 10 minutes ago. These were never
    // picked up by the webhook handler — mark them 'failed' for monitoring.
    // -------------------------------------------------------------------------

    const webhookRetryCutoff = new Date(Date.now() - 10 * 60 * 1000).toISOString()

    const { data: stalePendingEvents, error: pendingQueryError } = await supabaseClient
      .from('iap_webhook_events')
      .select('id, provider, event_type, notification_id, received_at')
      .eq('processing_status', 'pending')
      .is('processed_at', null)
      .lt('received_at', webhookRetryCutoff)

    if (pendingQueryError) {
      console.error('[CheckSubscriptionStatus] Error querying pending webhook events:', pendingQueryError)
    } else {
      const staleCount = stalePendingEvents?.length ?? 0
      console.log(`[CheckSubscriptionStatus] Task B: Found ${staleCount} stale pending webhook event(s)`)

      if (staleCount > 0) {
        // Log details before marking failed so ops can review
        stalePendingEvents?.forEach((event) => {
          console.log(
            `[CheckSubscriptionStatus] Stale webhook: id=${event.id} provider=${event.provider} ` +
            `event_type=${event.event_type} notification_id=${event.notification_id} ` +
            `received_at=${event.received_at}`
          )
        })

        const staleIds = stalePendingEvents?.map((e) => e.id) ?? []

        const { error: markFailedError } = await supabaseClient
          .from('iap_webhook_events')
          .update({
            processing_status: 'failed',
            error_message: 'Receipt not found after retry window - manual review needed'
          })
          .in('id', staleIds)

        if (markFailedError) {
          console.error('[CheckSubscriptionStatus] Error marking stale webhook events as failed:', markFailedError)
        } else {
          console.log(`[CheckSubscriptionStatus] Task B: Marked ${staleCount} stale webhook event(s) as failed`)
        }
      }
    }

    // -------------------------------------------------------------------------
    // Task C: Expire grace-period subscriptions
    // Find subscriptions where metadata->>'in_grace_period' = 'true' and
    // metadata->>'grace_period_expires_at' is in the past. Update status to
    // 'expired' and clear the grace period keys from metadata.
    // -------------------------------------------------------------------------

    const now = new Date().toISOString()

    const { data: graceExpiredSubscriptions, error: graceQueryError } = await supabaseClient
      .from('subscriptions')
      .select('id, user_id, provider, metadata')
      .filter('metadata->>in_grace_period', 'eq', 'true')
      .filter('metadata->>grace_period_expires_at', 'lt', now)
      .not('metadata', 'is', null)

    if (graceQueryError) {
      console.error('[CheckSubscriptionStatus] Error querying grace-period subscriptions:', graceQueryError)
    } else {
      const graceCount = graceExpiredSubscriptions?.length ?? 0
      console.log(`[CheckSubscriptionStatus] Task C: Found ${graceCount} grace-period expiry candidate(s)`)

      let graceClearedCount = 0

      for (const subscription of graceExpiredSubscriptions ?? []) {
        // Remove grace period keys from metadata while preserving other fields
        const updatedMetadata = { ...(subscription.metadata ?? {}) }
        delete updatedMetadata['in_grace_period']
        delete updatedMetadata['grace_period_expires_at']

        const { error: graceUpdateError } = await supabaseClient
          .from('subscriptions')
          .update({
            status: 'expired',
            metadata: updatedMetadata,
            updated_at: new Date().toISOString()
          })
          .eq('id', subscription.id)

        if (graceUpdateError) {
          console.error(
            `[CheckSubscriptionStatus] Error expiring grace-period subscription ${subscription.id}:`,
            graceUpdateError
          )
        } else {
          graceClearedCount++
          console.log(
            `[CheckSubscriptionStatus] Task C: Expired grace-period subscription ` +
            `id=${subscription.id} user_id=${subscription.user_id}`
          )
        }
      }

      console.log(`[CheckSubscriptionStatus] Task C: Cleared ${graceClearedCount} grace-period subscription(s)`)
    }

    const completedAt = new Date().toISOString()
    console.log(`[CheckSubscriptionStatus] Daily check completed at ${completedAt}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Subscription status check completed successfully',
        started_at: startedAt,
        completed_at: completedAt,
        results: {
          task_a_overdue_subscriptions_expired: expiredSubscriptions?.length ?? 0,
          task_b_stale_webhook_events_marked_failed: stalePendingEvents?.length ?? 0,
          task_c_grace_period_subscriptions_expired: graceExpiredSubscriptions?.length ?? 0
        }
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  } catch (error) {
    console.error('[CheckSubscriptionStatus] Unexpected error:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'An unexpected error occurred',
        timestamp: new Date().toISOString()
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})
