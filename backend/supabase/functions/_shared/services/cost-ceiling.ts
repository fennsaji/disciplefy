/**
 * A daily ceiling on what the app may spend with the model providers.
 *
 * The per-user limits stop one person running up a bill. This stops everyone
 * together doing it — a traffic spike, a loop in a cron, a bug that regenerates
 * the same guide. It is the last guard before the invoice.
 *
 * When it trips, generation stops and the reader is told plainly to come back
 * tomorrow. It does not serve placeholder content: on 18 July 2026 six such
 * guides were written into the cache and shown to readers as real studies, and
 * nobody noticed until the rows were counted in September.
 *
 * Cached and learning-path studies keep working while the ceiling is in force.
 * They cost nothing to serve, so there is no reason to take them away.
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

/** Dollars per day across every feature. Override with DAILY_COST_LIMIT_USD. */
const DEFAULT_DAILY_LIMIT_USD = 50

export interface CostCeilingResult {
  readonly withinBudget: boolean
  readonly spentUsd: number
  readonly limitUsd: number
}

/** The message a reader sees when the day's budget is gone. */
export const COST_CEILING_MESSAGE =
  "Today's study limit has been reached. Please try again tomorrow. Learning-path studies are still available."

export function dailyLimitUsd(): number {
  const raw = Deno.env.get('DAILY_COST_LIMIT_USD')
  const parsed = raw ? Number(raw) : NaN
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_DAILY_LIMIT_USD
}

/**
 * What the app has spent with the model providers since midnight UTC, and
 * whether that is still under the ceiling.
 *
 * A failure to read the spend returns "within budget". A metering problem must
 * not take the product down; the per-user limits still apply underneath.
 */
export async function checkCostCeiling(db: SupabaseClient): Promise<CostCeilingResult> {
  const limitUsd = dailyLimitUsd()
  const since = new Date()
  since.setUTCHours(0, 0, 0, 0)

  const { data, error } = await db
    .from('usage_logs')
    .select('llm_cost_usd')
    .gte('created_at', since.toISOString())
    .not('llm_cost_usd', 'is', null)

  if (error) {
    console.error('[CostCeiling] Could not read today\'s spend, allowing:', error.message)
    return { withinBudget: true, spentUsd: 0, limitUsd }
  }

  const spentUsd = (data ?? []).reduce(
    (total: number, row: { llm_cost_usd: number | string | null }) => total + Number(row.llm_cost_usd ?? 0),
    0,
  )

  const withinBudget = spentUsd < limitUsd
  if (!withinBudget) {
    console.warn(`[CostCeiling] Day's budget spent: $${spentUsd.toFixed(2)} of $${limitUsd.toFixed(2)}`)
  }

  return { withinBudget, spentUsd, limitUsd }
}
