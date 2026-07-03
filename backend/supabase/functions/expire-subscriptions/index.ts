/**
 * Expire Subscriptions - Scheduled Background Job (F10)
 *
 * Scans all active/pending_cancellation subscriptions whose current_period_end
 * has passed and marks them expired. This is the reconciliation safety net that
 * catches any subscriptions missed by real-time webhooks.
 *
 * Only expires subscriptions with a definitive current_period_end set:
 * - IAP subs (google_play, apple_appstore) always have it from receipt validation
 * - Razorpay subs only have it after the first charge webhook — those without it
 *   are deliberately skipped to avoid false-expiry on uncompleted checkouts.
 *
 * Schedule: Every hour via pg_cron / external scheduler
 *
 * POST /functions/v1/expire-subscriptions
 * Authorization: Bearer <service role key>
 */

import { createServiceRoleFunction } from '../_shared/core/function-factory.ts'

createServiceRoleFunction(async (_req, supabase) => {
  console.log('[expire-subscriptions] Starting reconciliation run...')

  const now = new Date().toISOString()

  // Expire active subs past their period end.
  // Skip rows where current_period_end IS NULL — these are Razorpay subs that
  // haven't received a charge event yet; expiring them would be a false revocation.
  const { data: expired, error: expireError } = await supabase
    .from('subscriptions')
    .update({
      status: 'expired',
      cancelled_at: now,
      cancellation_reason: 'Period end passed — expired by reconciliation job',
      updated_at: now
    })
    .in('status', ['active', 'pending_cancellation', 'trial', 'paused'])
    .not('current_period_end', 'is', null)
    .lt('current_period_end', now)
    .select('id, user_id, plan_type, provider, current_period_end')

  if (expireError) {
    console.error('[expire-subscriptions] DB update failed:', expireError)
    return { success: false, error: expireError.message, expired_count: 0 }
  }

  const expiredCount = expired?.length ?? 0

  if (expiredCount > 0) {
    console.log(`[expire-subscriptions] Expired ${expiredCount} subscription(s):`,
      expired?.map((s: { id: string; provider: string; current_period_end: string }) =>
        ({ id: s.id, provider: s.provider, period_end: s.current_period_end }))
    )
  } else {
    console.log('[expire-subscriptions] No subscriptions to expire')
  }

  return {
    success: true,
    expired_count: expiredCount,
    expired_ids: expired?.map((s: { id: string }) => s.id) ?? []
  }
})
