// backend/supabase/functions/_shared/utils/meeting-recurrence.ts
/**
 * Recurring fellowship meetings store only their first occurrence. These
 * helpers find later occurrences, so each one gets its own reminders, not
 * just the first.
 */

export type MeetingRecurrence = 'daily' | 'weekly' | 'monthly' | null | undefined

export type ReminderOffsetLabel = '1 hour' | '10 minutes'

/** How long before the occurrence a reminder of this label fires. */
export function reminderOffsetMs(label: string): number {
  return label === '10 minutes' ? 10 * 60_000 : 60 * 60_000
}

/** One recurrence step after `start` (same stepping the meeting list uses). */
export function stepOccurrence(start: Date, recurrence: MeetingRecurrence): Date | null {
  const next = new Date(start)
  switch (recurrence) {
    case 'daily': next.setDate(next.getDate() + 1); return next
    case 'weekly': next.setDate(next.getDate() + 7); return next
    case 'monthly': next.setMonth(next.getMonth() + 1); return next
    default: return null
  }
}

/**
 * The first occurrence after `occurrenceStart` whose reminder (start minus
 * the label's offset) is still in the future at `nowMs`. Null for a one-time
 * meeting.
 */
export function nextReminderOccurrence(
  occurrenceStart: Date,
  recurrence: MeetingRecurrence,
  offsetLabel: string,
  nowMs: number,
): Date | null {
  const offset = reminderOffsetMs(offsetLabel)
  let next = stepOccurrence(occurrenceStart, recurrence)
  // Bounded: a decade of daily occurrences is far beyond any real gap.
  for (let i = 0; next && i < 4000; i++) {
    if (next.getTime() - offset > nowMs) return next
    next = stepOccurrence(next, recurrence)
  }
  return null
}
