// ============================================================================
// notification-window quiet-hours tests
// ============================================================================
// The quiet-hours rule holds a push that would land in the recipient's
// 22:00–07:00 local night and releases it at 07:00 local. Getting the sign of
// the offset or the midnight wrap wrong silently delivers at 3 AM or delays a
// daytime push by nine hours, and neither is visible in a staging smoke test —
// so both edges, both signs and the wrap are pinned here.

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  isQuietHours,
  nextLocalTimeUtc,
  QUIET_HOURS_END_MINUTES,
  QUIET_HOURS_START_MINUTES,
} from './notification-window.ts'

/** UTC instant helper: utc(3, 30) is today at 03:30 UTC. */
function utc(hours: number, minutes = 0, seconds = 0): Date {
  return new Date(Date.UTC(2026, 8, 7, hours, minutes, seconds))
}

const IST = 330 // Asia/Kolkata, +5:30
const SYDNEY = 660 // +11:00
const NEW_YORK = -240 // EDT, -4:00
const LOS_ANGELES = -420 // PDT, -7:00

// ---------------------------------------------------------------------------
// isQuietHours — window shape
// ---------------------------------------------------------------------------

Deno.test('isQuietHours: 21:59 local is awake, 22:00 local is quiet', () => {
  // UTC+0 keeps local == UTC so the edge is unambiguous.
  assertEquals(isQuietHours(0, utc(21, 59)), false)
  assertEquals(isQuietHours(0, utc(22, 0)), true)
})

Deno.test('isQuietHours: 06:59 local is quiet, 07:00 local is awake', () => {
  assertEquals(isQuietHours(0, utc(6, 59)), true)
  assertEquals(isQuietHours(0, utc(7, 0)), false)
})

Deno.test('isQuietHours: the window wraps midnight', () => {
  assertEquals(isQuietHours(0, utc(23, 30)), true)
  assertEquals(isQuietHours(0, utc(0, 0)), true)
  assertEquals(isQuietHours(0, utc(3, 0)), true)
  // ...and midday is never quiet.
  assertEquals(isQuietHours(0, utc(12, 0)), false)
})

Deno.test('isQuietHours: constants describe 22:00–07:00', () => {
  assertEquals(QUIET_HOURS_START_MINUTES, 1320)
  assertEquals(QUIET_HOURS_END_MINUTES, 420)
})

// ---------------------------------------------------------------------------
// isQuietHours — offsets
// ---------------------------------------------------------------------------

Deno.test('isQuietHours: positive offset (IST +330)', () => {
  // 01:00 UTC = 06:30 IST → still night for them.
  assertEquals(isQuietHours(IST, utc(1, 0)), true)
  // 01:30 UTC = 07:00 IST → morning, send now.
  assertEquals(isQuietHours(IST, utc(1, 30)), false)
  // 18:00 UTC = 23:30 IST → night again.
  assertEquals(isQuietHours(IST, utc(18, 0)), true)
})

Deno.test('isQuietHours: large positive offset (Sydney +660) wraps the UTC day', () => {
  // 12:00 UTC = 23:00 next day in Sydney → quiet.
  assertEquals(isQuietHours(SYDNEY, utc(12, 0)), true)
  // 20:00 UTC = 07:00 next day in Sydney → awake.
  assertEquals(isQuietHours(SYDNEY, utc(20, 0)), false)
  // 03:00 UTC = 14:00 Sydney → awake.
  assertEquals(isQuietHours(SYDNEY, utc(3, 0)), false)
})

Deno.test('isQuietHours: negative offsets (US) wrap backwards past midnight', () => {
  // 03:00 UTC = 23:00 previous day in New York → quiet.
  assertEquals(isQuietHours(NEW_YORK, utc(3, 0)), true)
  // 11:00 UTC = 07:00 New York → awake exactly at the boundary.
  assertEquals(isQuietHours(NEW_YORK, utc(11, 0)), false)
  // 10:59 UTC = 06:59 New York → still quiet.
  assertEquals(isQuietHours(NEW_YORK, utc(10, 59)), true)
  // 05:00 UTC = 22:00 previous day in Los Angeles → quiet at the boundary.
  assertEquals(isQuietHours(LOS_ANGELES, utc(5, 0)), true)
  assertEquals(isQuietHours(LOS_ANGELES, utc(4, 59)), false)
})

// ---------------------------------------------------------------------------
// isQuietHours — unknown offset
// ---------------------------------------------------------------------------

Deno.test('isQuietHours: a null offset is never quiet, so unknown users are sent now', () => {
  // 03:00 UTC is the middle of the night on the server's own clock — the
  // tempting wrong answer. Unknown must still mean send.
  assertEquals(isQuietHours(null, utc(3, 0)), false)
  assertEquals(isQuietHours(null, utc(23, 0)), false)
  assertEquals(isQuietHours(null, utc(12, 0)), false)
})

// ---------------------------------------------------------------------------
// nextLocalTimeUtc
// ---------------------------------------------------------------------------

const SEVEN_AM = 7 * 60

Deno.test('nextLocalTimeUtc: IST night resolves to 01:30 UTC (07:00 IST) the same day', () => {
  // 18:30 UTC = 00:00 IST tomorrow. Their 07:00 is 01:30 UTC, seven hours out.
  const at = nextLocalTimeUtc(IST, SEVEN_AM, utc(18, 30))
  assertEquals(at.toISOString(), '2026-09-08T01:30:00.000Z')
})

Deno.test('nextLocalTimeUtc: IST just before 07:00 resolves to later the same morning', () => {
  // 01:00 UTC = 06:30 IST → 30 minutes ahead.
  const at = nextLocalTimeUtc(IST, SEVEN_AM, utc(1, 0))
  assertEquals(at.toISOString(), '2026-09-07T01:30:00.000Z')
})

Deno.test('nextLocalTimeUtc: negative offset (New York) resolves to 11:00 UTC', () => {
  // 04:00 UTC = 00:00 New York → their 07:00 is 11:00 UTC.
  const at = nextLocalTimeUtc(NEW_YORK, SEVEN_AM, utc(4, 0))
  assertEquals(at.toISOString(), '2026-09-07T11:00:00.000Z')
})

Deno.test('nextLocalTimeUtc: Los Angeles late evening rolls to the next UTC day', () => {
  // 06:00 UTC = 23:00 previous day in LA → their 07:00 is 14:00 UTC same day.
  const at = nextLocalTimeUtc(LOS_ANGELES, SEVEN_AM, utc(6, 0))
  assertEquals(at.toISOString(), '2026-09-07T14:00:00.000Z')
})

Deno.test('nextLocalTimeUtc: Sydney +660 crosses the UTC day boundary', () => {
  // 13:00 UTC = 00:00 Sydney (next day) → their 07:00 is 20:00 UTC.
  const at = nextLocalTimeUtc(SYDNEY, SEVEN_AM, utc(13, 0))
  assertEquals(at.toISOString(), '2026-09-07T20:00:00.000Z')
})

Deno.test('nextLocalTimeUtc: past the target today rolls to tomorrow, not backwards', () => {
  // 12:00 UTC = 12:00 local at UTC+0 — 07:00 has gone, so it is tomorrow's.
  const at = nextLocalTimeUtc(0, SEVEN_AM, utc(12, 0))
  assertEquals(at.toISOString(), '2026-09-08T07:00:00.000Z')
})

Deno.test('nextLocalTimeUtc: exactly at the target returns now, never tomorrow', () => {
  const now = utc(7, 0, 42)
  const at = nextLocalTimeUtc(0, SEVEN_AM, now)
  assertEquals(at.getTime(), now.getTime())
})

Deno.test('nextLocalTimeUtc: result is truncated to the target minute', () => {
  // A push triggered at 18:30:47 must still queue for a clean :00.
  const at = nextLocalTimeUtc(IST, SEVEN_AM, utc(18, 30, 47))
  assertEquals(at.getUTCSeconds(), 0)
  assertEquals(at.getUTCMilliseconds(), 0)
})

Deno.test('nextLocalTimeUtc: the returned instant really reads 07:00 on the local clock', () => {
  for (const offset of [IST, SYDNEY, NEW_YORK, LOS_ANGELES, 0, -570, 345]) {
    for (const hour of [0, 3, 7, 12, 18, 22, 23]) {
      const at = nextLocalTimeUtc(offset, SEVEN_AM, utc(hour))
      const localMinutes =
        ((at.getUTCHours() * 60 + at.getUTCMinutes() + offset) % 1440 + 1440) % 1440
      assertEquals(
        localMinutes,
        SEVEN_AM,
        `offset ${offset} at ${hour}:00 UTC resolved to local ${localMinutes}`,
      )
    }
  }
})

Deno.test('nextLocalTimeUtc: a queued row is never scheduled more than 24h out', () => {
  for (const offset of [IST, SYDNEY, NEW_YORK, LOS_ANGELES, 0]) {
    const now = utc(23, 17)
    const at = nextLocalTimeUtc(offset, SEVEN_AM, now)
    const hoursOut = (at.getTime() - now.getTime()) / 3_600_000
    assertEquals(hoursOut >= 0 && hoursOut < 24, true, `offset ${offset} → ${hoursOut}h`)
  }
})
