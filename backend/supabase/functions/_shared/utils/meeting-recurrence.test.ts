// Run with: deno test meeting-recurrence.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { nextReminderOccurrence, reminderOffsetMs } from './meeting-recurrence.ts'

const start = new Date('2026-10-01T18:00:00Z')

Deno.test('a one-time meeting has no further reminders', () => {
  assertEquals(nextReminderOccurrence(start, null, '1 hour', start.getTime()), null)
})

Deno.test('a weekly meeting is reminded again the next week', () => {
  const after = nextReminderOccurrence(start, 'weekly', '1 hour', start.getTime())
  assertEquals(after?.toISOString(), '2026-10-08T18:00:00.000Z')
})

Deno.test('missed occurrences are skipped to the next one still ahead', () => {
  // Cron down for 10 days; daily meeting resumes at the first future reminder.
  const now = new Date('2026-10-11T17:30:00Z').getTime() // 30 min before the 11th's start
  assertEquals(nextReminderOccurrence(start, 'daily', '1 hour', now)?.toISOString(), '2026-10-12T18:00:00.000Z')
  assertEquals(nextReminderOccurrence(start, 'daily', '10 minutes', now)?.toISOString(), '2026-10-11T18:00:00.000Z')
})

Deno.test('offsets', () => {
  assertEquals(reminderOffsetMs('1 hour'), 3_600_000)
  assertEquals(reminderOffsetMs('10 minutes'), 600_000)
})
