// Run with: deno test exchange-rate.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { FALLBACK_USD_TO_INR, resetExchangeRateCache, usdToInrRate } from './exchange-rate.ts'

/**
 * The rate was hardcoded in four places and drifted more than a tenth off the
 * real one, understating every INR figure the dashboard showed. It now comes
 * from system_config, so the things worth pinning are: a configured rate is
 * used, an unusable one is refused rather than trusted, and a read failure
 * still yields a sane number instead of zero.
 */

/** Minimal stand-in for the supabase-js chain `usdToInrRate` calls. */
function dbReturning(value: unknown, error: unknown = null) {
  return {
    from() {
      return {
        select() {
          return {
            eq() {
              return {
                eq() {
                  return { maybeSingle: () => Promise.resolve({ data: value === undefined ? null : { value }, error }) }
                },
              }
            },
          }
        },
      }
    },
  }
}

Deno.test('a configured rate is used', async () => {
  resetExchangeRateCache()
  assertEquals(await usdToInrRate(dbReturning('95.5')), 95.5)
})

Deno.test('with no database the fallback applies', async () => {
  resetExchangeRateCache()
  assertEquals(await usdToInrRate(), FALLBACK_USD_TO_INR)
})

Deno.test('a missing row falls back rather than reading as zero', async () => {
  resetExchangeRateCache()
  assertEquals(await usdToInrRate(dbReturning(undefined)), FALLBACK_USD_TO_INR)
})

Deno.test('a read error falls back rather than reading as zero', async () => {
  resetExchangeRateCache()
  assertEquals(await usdToInrRate(dbReturning('95.5', { message: 'boom' })), FALLBACK_USD_TO_INR)
})

Deno.test('an out-of-band rate is refused, not trusted', async () => {
  // A decimal point in the wrong place would otherwise distort every INR
  // figure in the app, in whichever direction the typo went.
  for (const bad of ['0', '9.55', '955', '-95', 'ninety five', '']) {
    resetExchangeRateCache()
    assertEquals(await usdToInrRate(dbReturning(bad)), FALLBACK_USD_TO_INR, `accepted ${bad}`)
  }
})

Deno.test('the fallback is itself a plausible rate', () => {
  // It is the number every INR figure falls back to, so a stale constant here
  // is the very failure this module exists to end.
  assertEquals(FALLBACK_USD_TO_INR >= 50 && FALLBACK_USD_TO_INR <= 200, true)
})

Deno.test('the rate is cached, then released on reset', async () => {
  resetExchangeRateCache()
  assertEquals(await usdToInrRate(dbReturning('90')), 90)
  // Second call must not re-read: a different db would otherwise change it.
  assertEquals(await usdToInrRate(dbReturning('120')), 90)

  resetExchangeRateCache()
  assertEquals(await usdToInrRate(dbReturning('120')), 120)
})
