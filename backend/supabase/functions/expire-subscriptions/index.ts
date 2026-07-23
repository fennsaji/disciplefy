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

/**
 * Cancel a Razorpay subscription via the REST API.
 *
 * Deliberately does NOT go through PaymentProviderFactory: that pulls in
 * `npm:razorpay`, whose import chain fails to boot this worker (BOOT_ERROR).
 * A scheduled job only needs this one endpoint, so a direct fetch keeps the
 * cold start light and removes the dependency entirely.
 */
/** Live subscription state as Razorpay reports it. */
interface RazorpaySubscriptionState {
  status: string
  paid_count: number
  current_start: number | null
  current_end: number | null
  charge_at: number | null
}

/** Fetch a subscription from Razorpay. Returns null if it cannot be read. */
async function fetchRazorpaySubscription(
  providerSubId: string
): Promise<RazorpaySubscriptionState | null> {
  const keyId = Deno.env.get('RAZORPAY_KEY_ID')
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')

  if (!keyId || !keySecret) {
    throw new Error('Razorpay credentials not configured')
  }

  const response = await fetch(
    `https://api.razorpay.com/v1/subscriptions/${providerSubId}`,
    {
      headers: { 'Authorization': `Basic ${btoa(`${keyId}:${keySecret}`)}` }
    }
  )

  if (!response.ok) return null

  const body = await response.json()
  return {
    status: body.status,
    paid_count: body.paid_count ?? 0,
    current_start: body.current_start ?? null,
    current_end: body.current_end ?? null,
    charge_at: body.charge_at ?? null
  }
}

/** Unix seconds → ISO string, or null. */
function toIso(seconds: number | null): string | null {
  return seconds ? new Date(seconds * 1000).toISOString() : null
}

async function cancelRazorpaySubscription(providerSubId: string): Promise<void> {
  const keyId = Deno.env.get('RAZORPAY_KEY_ID')
  const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')

  if (!keyId || !keySecret) {
    throw new Error('Razorpay credentials not configured')
  }

  const response = await fetch(
    `https://api.razorpay.com/v1/subscriptions/${providerSubId}/cancel`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${btoa(`${keyId}:${keySecret}`)}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ cancel_at_cycle_end: 0 })
    }
  )

  if (!response.ok) {
    const detail = await response.text()
    throw new Error(`Razorpay cancel failed (${response.status}): ${detail}`)
  }
}

/**
 * How long an unpaid 'created' subscription may sit before the sweep clears it.
 *
 * A Razorpay authorization link stays valid for a while, so this is set long
 * enough that a user slowly working through checkout is never cut off. Anything
 * still unpaid after this window is an abandoned checkout.
 */
const ABANDONED_CHECKOUT_MINUTES = Number(
  Deno.env.get('ABANDONED_CHECKOUT_MINUTES') ?? '30'
)

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

  // ---------------------------------------------------------------------------
  // Abandoned-checkout sweep
  // ---------------------------------------------------------------------------
  // A 'created' row is written when a checkout is opened but not yet paid. If the
  // user closes the tab, no provider webhook ever fires — Razorpay has no event
  // for "user walked away" — so nothing else cleans these up. They then block the
  // one-active-per-user unique index (which does not exclude 'created'), breaking
  // every future subscription attempt for that user until something clears them.
  //
  // The expiry pass above cannot catch these: it only looks at active-ish statuses
  // and requires a non-null current_period_end, which unpaid Razorpay rows lack.
  const abandonedCutoff = new Date(
    Date.now() - ABANDONED_CHECKOUT_MINUTES * 60 * 1000
  ).toISOString()

  // ---------------------------------------------------------------------------
  // Razorpay activation reconciliation — MUST run before the sweep below
  // ---------------------------------------------------------------------------
  // For Razorpay, `subscription.activated` is the ONLY thing that moves a row
  // from 'created' to 'active'. If that webhook is missed — outage, deploy
  // window, no public URL in local dev — the customer has paid but stays on
  // their old plan forever, with no self-healing path.
  //
  // Ordering matters: without this pass running first, a paid-but-unwebhooked
  // row older than the abandon cutoff would be cancelled by the sweep below —
  // revoking a subscription the user actually paid for.
  const { data: pendingRows, error: pendingError } = await supabase
    .from('subscriptions')
    .select('id, user_id, provider, provider_subscription_id, provider_metadata, created_at')
    .eq('status', 'created')
    .eq('provider', 'razorpay')

  if (pendingError) {
    console.error('[expire-subscriptions] Pending-activation query failed:', pendingError)
  }

  const activatedIds: string[] = []
  const paidProviderSubIds = new Set<string>()

  for (const pendingRow of pendingRows ?? []) {
    const pending = pendingRow as {
      id: string
      user_id: string
      provider_subscription_id: string | null
      provider_metadata: { scheduled_downgrade?: boolean } | null
    }

    // A scheduled downgrade is meant to sit in 'created' until its start date.
    if (pending.provider_metadata?.scheduled_downgrade === true) continue
    if (!pending.provider_subscription_id) continue

    let live: RazorpaySubscriptionState | null = null
    try {
      live = await fetchRazorpaySubscription(pending.provider_subscription_id)
    } catch (fetchErr) {
      console.error('[expire-subscriptions] Razorpay lookup failed (skipping):', {
        providerSubId: pending.provider_subscription_id,
        error: fetchErr instanceof Error ? fetchErr.message : String(fetchErr)
      })
      // Unknown state — protect it from the sweep rather than risk cancelling
      // a paid subscription on the strength of a failed HTTP call.
      paidProviderSubIds.add(pending.provider_subscription_id)
      continue
    }

    if (!live) continue

    const isPaid = live.status === 'active' ||
      live.status === 'authenticated' ||
      live.paid_count > 0

    if (!isPaid) continue

    // Never let the sweep touch this row.
    paidProviderSubIds.add(pending.provider_subscription_id)

    const { error: activateError } = await supabase
      .from('subscriptions')
      .update({
        status: 'active',
        paid_count: live.paid_count,
        current_period_start: toIso(live.current_start),
        current_period_end: toIso(live.current_end),
        next_billing_at: toIso(live.charge_at),
        updated_at: now
      })
      .eq('id', pending.id)
      .eq('status', 'created') // guard against a webhook landing concurrently

    if (activateError) {
      console.error('[expire-subscriptions] Failed to activate paid subscription:', {
        id: pending.id, activateError
      })
      continue
    }

    activatedIds.push(pending.id)
    console.log('[expire-subscriptions] Activated paid subscription missed by webhook:', pending.id)

    // Retire the old plan this upgrade replaces — the job subscription.activated
    // would normally have done. Only rows parked by an upgrade are touched.
    const { data: parkedForUpgrade } = await supabase
      .from('subscriptions')
      .select('id, provider_metadata')
      .eq('user_id', pending.user_id)
      .eq('status', 'pending_cancellation')

    for (const oldRow of parkedForUpgrade ?? []) {
      const old = oldRow as {
        id: string
        provider_metadata: { parked_from_status?: string } | null
      }
      if (!old.provider_metadata?.parked_from_status) continue

      const cleaned: Record<string, unknown> = { ...old.provider_metadata }
      delete cleaned.parked_from_status

      await supabase
        .from('subscriptions')
        .update({
          status: 'cancelled',
          cancelled_at: now,
          cancel_at_cycle_end: false,
          cancellation_reason: 'Superseded by an activated upgrade',
          provider_metadata: cleaned,
          updated_at: now
        })
        .eq('id', old.id)
        .eq('status', 'pending_cancellation')

      console.log('[expire-subscriptions] Retired superseded plan:', old.id)
    }
  }

  const { data: abandoned, error: abandonedError } = await supabase
    .from('subscriptions')
    .select('id, user_id, provider, provider_subscription_id, provider_metadata, created_at')
    .eq('status', 'created')
    .lt('created_at', abandonedCutoff)

  if (abandonedError) {
    console.error('[expire-subscriptions] Abandoned-checkout query failed:', abandonedError)
    return {
      success: false,
      error: abandonedError.message,
      expired_count: expiredCount,
      abandoned_count: 0
    }
  }

  // Scheduled downgrades are also 'created' and legitimately stay that way until
  // their start date, which can be weeks out — never sweep those. Rows the
  // reconciliation above found to be paid (or could not read) are excluded too:
  // cancelling one of those would revoke a subscription the user paid for.
  const sweepable = (abandoned ?? []).filter((s: {
    provider_subscription_id: string | null
    provider_metadata: { scheduled_downgrade?: boolean } | null
  }) =>
    s.provider_metadata?.scheduled_downgrade !== true &&
    !(s.provider_subscription_id && paidProviderSubIds.has(s.provider_subscription_id))
  )

  const sweptIds: string[] = []
  const unparkedIds: string[] = []

  for (const row of sweepable) {
    const sub = row as {
      id: string
      provider: string
      provider_subscription_id: string | null
    }

    // Cancel provider-side first so the dangling subscription can never bill.
    if (sub.provider === 'razorpay' && sub.provider_subscription_id) {
      try {
        await cancelRazorpaySubscription(sub.provider_subscription_id)
        console.log('[expire-subscriptions] Cancelled abandoned Razorpay sub:', sub.provider_subscription_id)
      } catch (cancelErr) {
        // Non-fatal: it may already be cancelled or expired provider-side. Still
        // clear the DB row — leaving it would keep the user's index slot blocked.
        console.error('[expire-subscriptions] Provider cancel failed (non-fatal):', {
          providerSubId: sub.provider_subscription_id,
          error: cancelErr instanceof Error ? cancelErr.message : String(cancelErr)
        })
      }
    }

    const { error: clearError } = await supabase
      .from('subscriptions')
      .update({
        status: 'cancelled',
        cancelled_at: now,
        cancellation_reason: 'Abandoned checkout — cleared by reconciliation job',
        updated_at: now
      })
      .eq('id', sub.id)
      .eq('status', 'created') // guard: skip if it activated since the query

    if (clearError) {
      console.error('[expire-subscriptions] Failed to clear abandoned row:', { id: sub.id, clearError })
      continue
    }

    sweptIds.push(sub.id)

    // Un-park the subscription this checkout was upgrading from.
    //
    // create-subscription-v2 parks the old sub as 'pending_cancellation' to free
    // the one-active-per-user index slot while checkout is pending, and relies on
    // the subscription.activated webhook to finish the job. If the user never pays
    // that webhook never fires, so clearing the abandoned row without restoring the
    // old one would leave the user parked — showing a cancellation they never asked
    // for — forever. Parking and un-parking have to be the same operation.
    const { data: parkedRows, error: parkedError } = await supabase
      .from('subscriptions')
      .select('id, status, provider_metadata')
      .eq('user_id', (row as { user_id: string }).user_id)
      .eq('status', 'pending_cancellation')

    if (parkedError) {
      console.error('[expire-subscriptions] Parked-sub lookup failed:', parkedError)
      continue
    }

    for (const parkedRow of parkedRows ?? []) {
      const parked = parkedRow as {
        id: string
        provider_metadata: { parked_from_status?: string } | null
      }
      const restoreTo = parked.provider_metadata?.parked_from_status

      // No marker means this is a real cancellation (user-requested, or a
      // scheduled downgrade) — never touch it. Guessing a status here would
      // resurrect subscriptions the user deliberately cancelled.
      if (!restoreTo) continue

      const restoredMetadata: Record<string, unknown> = { ...parked.provider_metadata }
      delete restoredMetadata.parked_from_status

      const { error: unparkError } = await supabase
        .from('subscriptions')
        .update({
          status: restoreTo,
          cancel_at_cycle_end: false,
          cancellation_reason: null,
          cancelled_at: null,
          provider_metadata: restoredMetadata,
          updated_at: now
        })
        .eq('id', parked.id)
        .eq('status', 'pending_cancellation') // guard against a concurrent change

      if (unparkError) {
        console.error('[expire-subscriptions] Failed to un-park subscription:', { id: parked.id, unparkError })
        continue
      }

      unparkedIds.push(parked.id)
      console.log(`[expire-subscriptions] Un-parked subscription ${parked.id} back to '${restoreTo}'`)
    }
  }

  if (sweptIds.length > 0) {
    console.log(`[expire-subscriptions] Cleared ${sweptIds.length} abandoned checkout(s)`)
  } else {
    console.log('[expire-subscriptions] No abandoned checkouts to clear')
  }

  return {
    success: true,
    expired_count: expiredCount,
    expired_ids: expired?.map((s: { id: string }) => s.id) ?? [],
    activated_count: activatedIds.length,
    activated_ids: activatedIds,
    abandoned_count: sweptIds.length,
    abandoned_ids: sweptIds,
    unparked_count: unparkedIds.length,
    unparked_ids: unparkedIds
  }
})
