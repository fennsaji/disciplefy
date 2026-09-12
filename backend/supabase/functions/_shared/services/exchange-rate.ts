// backend/supabase/functions/_shared/services/exchange-rate.ts
/**
 * One USD→INR rate for the whole app, read from `system_config`.
 *
 * The rate used to be a hardcoded constant in four separate places — two TypeScript
 * services, the `log_usage` SQL function, and a fallback in the P&L endpoint — all
 * stuck at 83.5 (or 84.0) long after the rupee had moved past 95. Every INR figure
 * the dashboard showed was understated by more than a tenth, and correcting it meant
 * a deploy plus a migration.
 *
 * It now lives in `system_config` under `usd_to_inr_rate`, editable from the admin
 * dashboard like the other money settings. The constant below is only the last
 * resort when config cannot be read at all.
 */

// deno-lint-ignore no-explicit-any
type SupabaseClient = any

/**
 * Used only when `system_config` cannot be read.
 *
 * Deliberately near the real rate rather than conservative in either direction:
 * this figure converts costs for reporting, so being wrong low understates what
 * the app spends and being wrong high overstates it. Keep it roughly current.
 */
export const FALLBACK_USD_TO_INR = 95.5

/** Config is read once per instance; a change takes effect within the minute. */
const RATE_CACHE_MS = 60_000
let cachedRate: { value: number; readAt: number } | null = null

/**
 * The configured USD→INR rate, falling back to {@link FALLBACK_USD_TO_INR}.
 *
 * Cached briefly so a busy minute does not read config on every request.
 */
export async function usdToInrRate(db?: SupabaseClient): Promise<number> {
  if (cachedRate && Date.now() - cachedRate.readAt < RATE_CACHE_MS) {
    return cachedRate.value
  }

  if (db) {
    const { data, error } = await db
      .from('system_config')
      .select('value')
      .eq('key', 'usd_to_inr_rate')
      .eq('is_active', true)
      .maybeSingle()

    if (!error && data?.value) {
      const configured = Number(data.value)
      // A nonsense rate would silently distort every INR figure in the app, so
      // an out-of-range value is ignored rather than trusted. The band is wide
      // enough for any plausible rate and narrow enough to catch a typo such as
      // a decimal point in the wrong place.
      if (Number.isFinite(configured) && configured >= 50 && configured <= 200) {
        cachedRate = { value: configured, readAt: Date.now() }
        return configured
      }
      console.warn(`[ExchangeRate] Ignoring unusable configured rate: ${data.value}`)
    }
  }

  cachedRate = { value: FALLBACK_USD_TO_INR, readAt: Date.now() }
  return FALLBACK_USD_TO_INR
}

/** Forgets the cached rate, so a change in admin applies at once. */
export function resetExchangeRateCache(): void {
  cachedRate = null
}
