import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { limitMessage, startOfDay, startOfMonth } from './fresh-study-limits.ts'

Deno.test('month window starts at midnight UTC on the first', () => {
  const start = startOfMonth(new Date('2026-09-09T18:32:00Z'))
  assertEquals(start.toISOString(), '2026-09-01T00:00:00.000Z')
})

Deno.test('day window starts at midnight UTC today', () => {
  const start = startOfDay(new Date('2026-09-09T18:32:00Z'))
  assertEquals(start.toISOString(), '2026-09-09T00:00:00.000Z')
})

Deno.test('the monthly message says the catalogue is still open', () => {
  const message = limitMessage({ allowed: false, limit: 'monthly_fresh_studies', used: 20, cap: 20 })
  assertEquals(
    message,
    "You have used this month's new studies. All learning-path studies are still open. Upgrade for more.",
  )
})

Deno.test('the sermon message points at tomorrow, not an upgrade', () => {
  const message = limitMessage({ allowed: false, limit: 'daily_sermons', used: 2, cap: 2 })
  assertEquals(message, "You have made today's sermon outlines. Please try again tomorrow.")
})
