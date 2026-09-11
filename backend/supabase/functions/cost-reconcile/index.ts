/**
 * Checks our own cost figures against what Anthropic billed, one day at a time.
 *
 * Runs daily from rs-backend. Reconciles yesterday by default, which is the
 * most recent day whose billing has settled; pass `{"day": "2026-09-08"}` to
 * check another. Anthropic's data usually appears within five minutes of a
 * request, so yesterday is comfortably complete.
 *
 * A gap beyond a few percent means the price table has drifted from reality:
 * a price changed, a model appeared that the table does not know, or the cache
 * accounting is wrong again. Every budget in the app reads our figure, so a
 * drift is worth seeing early.
 */

import { createServiceRoleFunction } from '../_shared/core/function-factory.ts'
import { reconcileDay, yesterdayUtc } from '../_shared/services/cost-reconciliation.ts'

/** Beyond this, our arithmetic is wrong enough to look at. */
const ACCEPTABLE_GAP_PERCENT = 5

createServiceRoleFunction(async (req, supabase) => {
  let day = yesterdayUtc()
  try {
    const body = await req.json()
    if (typeof body?.day === 'string') day = body.day
  } catch {
    // No body: a scheduled run, reconciling yesterday.
  }

  const result = await reconcileDay(supabase, day)

  const note = !result.configured
    ? result.reason
    : Math.abs(result.gapPercent) > ACCEPTABLE_GAP_PERCENT
    ? `Our figure is off by ${result.gapPercent.toFixed(1)}%; check the price table`
    : null

  const { error } = await supabase.from('cost_reconciliation').upsert({
    day,
    our_usd: result.ourUsd,
    anthropic_usd: result.anthropicUsd,
    gap_usd: result.gapUsd,
    gap_percent: result.gapPercent,
    configured: result.configured,
    note,
    checked_at: new Date().toISOString(),
  }, { onConflict: 'day' })

  if (error) console.error('[cost-reconcile] could not record the comparison:', error.message)

  if (!result.configured) {
    console.log(`[cost-reconcile] ${day}: not configured — ${result.reason}`)
  } else if (note) {
    console.warn(
      `[cost-reconcile] ${day}: we recorded $${result.ourUsd.toFixed(4)}, ` +
      `Anthropic billed $${result.anthropicUsd.toFixed(4)} (${result.gapPercent.toFixed(1)}%)`,
    )
  } else {
    console.log(
      `[cost-reconcile] ${day}: agrees within ${ACCEPTABLE_GAP_PERCENT}% ` +
      `(ours $${result.ourUsd.toFixed(4)}, Anthropic $${result.anthropicUsd.toFixed(4)})`,
    )
  }

  return {
    success: true,
    day,
    configured: result.configured,
    our_usd: Number(result.ourUsd.toFixed(6)),
    anthropic_usd: Number(result.anthropicUsd.toFixed(6)),
    gap_usd: Number(result.gapUsd.toFixed(6)),
    gap_percent: Number(result.gapPercent.toFixed(3)),
    within_tolerance: result.configured ? Math.abs(result.gapPercent) <= ACCEPTABLE_GAP_PERCENT : null,
    note,
  }
}, { allowedMethods: ['POST', 'GET'] })
