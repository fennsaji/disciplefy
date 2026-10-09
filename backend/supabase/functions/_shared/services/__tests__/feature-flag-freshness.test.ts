import { assert, assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { FEATURE_FLAGS_CACHE_TTL_MS, mapFeatureFlagRow } from '../feature-flag-service.ts'
import { systemConfigCacheControl } from '../../../system-config/cache-control.ts'

// An admin toggle must reach the app within about a minute: the flags cache
// in each edge worker may not hold a row for long.
Deno.test('feature flags cache holds rows for at most a minute', () => {
  assert(FEATURE_FLAGS_CACHE_TTL_MS <= 60_000)
})

// The app keeps its own copy, so a browser must not serve a stored
// system-config response after an admin toggle.
Deno.test('system-config responses are never served from an HTTP cache', () => {
  for (const tester of [false, true]) {
    const header = systemConfigCacheControl(tester)
    assert(!/max-age=[1-9]/.test(header), header)
    assert(!header.includes('stale-while-revalidate'), header)
    assert(/no-cache|no-store/.test(header), header)
  }
})

Deno.test('row mapping keeps the admin-set rollout percentage, including 0', () => {
  const row = {
    feature_key: 'guest_mode',
    feature_name: 'Guest mode',
    is_enabled: true,
    enabled_for_plans: null,
    rollout_percentage: 0,
    display_mode: null,
    metadata: null,
    allow_tester_bypass: null,
  }
  const flag = mapFeatureFlagRow(row)
  assertEquals(flag.isEnabled, true)
  assertEquals(flag.rolloutPercentage, 0)
  assertEquals(flag.enabledForPlans, [])
  assertEquals(flag.displayMode, 'hide')
  assertEquals(flag.allowTesterBypass, false)
  assertEquals(mapFeatureFlagRow({ ...row, rollout_percentage: null }).rolloutPercentage, 100)
})
