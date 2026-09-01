// ============================================================================
// Notification Delivery Window
// ============================================================================
// Shared local-time window math for scheduled push notifications.
//
// WHY THIS EXISTS
// ---------------
// Notifications used to be matched with a narrow ±90 minute window around a
// single target hour, evaluated against the UTC hour the cron happened to run
// in. That made delivery entirely dependent on GitHub Actions firing a specific
// hour's cron on time — and scheduled workflows are best-effort: they get
// delayed and silently dropped under load. Each timezone band mapped to exactly
// ONE usable UTC hour, so a single dropped cron meant that band received
// nothing at all that day, with no retry.
//
// Instead we treat the target as "deliver once the user's local time has
// reached <target>, any time within the following <window>". Every hourly run
// then acts as a catch-up for the ones that were dropped, and the per-day
// dedup (see getAlreadySentUserIds) keeps it to one send per user per day.

/** Minutes in a day. */
const MINUTES_PER_DAY = 1440

/**
 * Default catch-up window. A notification stays deliverable for this long after
 * the user's local target time, so a dropped or delayed cron is picked up by a
 * later run instead of being lost. Kept short enough that a "good morning"
 * notification can never arrive in the evening.
 */
export const DEFAULT_CATCH_UP_WINDOW_MINUTES = 6 * 60

/**
 * Rolling dedup window for windowed notifications.
 *
 * These must NOT dedup on the UTC calendar day: at UTC+7 and later the local
 * delivery window straddles UTC midnight (an Australia/UTC+9:30 user's 6 AM
 * window spans UTC 20:30–02:30), so a calendar-day check resets halfway through
 * and sends a second notification.
 *
 * The value must satisfy BOTH bounds (see the invariant check below):
 *
 *   catch-up window < DEDUP_LOOKBACK_HOURS < 24
 *
 * Too low and a user can be sent twice within a single delivery window. Too
 * high — 24 or more — and the next day's send is suppressed because it falls
 * only 24 hours after the previous one, degrading to every-other-day delivery.
 *
 * At 20 h with a 6 h window: a send at the very end of one day's window leaves
 * the last 4 h of the next day's window still usable, so daily delivery holds
 * even when a send runs late.
 */
export const DEDUP_LOOKBACK_HOURS = 20

// Guard the invariant at module load so widening the catch-up window can never
// silently break daily delivery or start double-sending.
{
  const windowHours = DEFAULT_CATCH_UP_WINDOW_MINUTES / 60
  if (DEDUP_LOOKBACK_HOURS <= windowHours || DEDUP_LOOKBACK_HOURS >= 24) {
    throw new Error(
      `Invalid notification dedup config: expected ${windowHours} < DEDUP_LOOKBACK_HOURS < 24, ` +
      `got ${DEDUP_LOOKBACK_HOURS}. Below the catch-up window it double-sends; at 24+ it drops days.`
    )
  }
}

/**
 * Converts the current UTC instant into the user's local minutes-from-midnight.
 *
 * @param timezoneOffsetMinutes - User's UTC offset in minutes (IST = +330)
 * @param now - Instant to evaluate (defaults to current time)
 * @returns Minutes since the user's local midnight, 0–1439
 */
export function localMinutesFromMidnight(
  timezoneOffsetMinutes: number,
  now: Date = new Date()
): number {
  const utcMinutes = now.getUTCHours() * 60 + now.getUTCMinutes()
  return ((utcMinutes + timezoneOffsetMinutes) % MINUTES_PER_DAY + MINUTES_PER_DAY) % MINUTES_PER_DAY
}

/**
 * Whether a user is inside their delivery window right now.
 *
 * The window runs from the target local time forward — never backwards — so a
 * user is only notified at or after their intended hour, and only for the
 * catch-up period after it.
 *
 * Note this deliberately does NOT wrap past local midnight: a window that would
 * spill into the next day is clamped, because delivering yesterday's 8 AM
 * notification at 1 AM today is worse than skipping it.
 *
 * @param timezoneOffsetMinutes - User's UTC offset in minutes (IST = +330)
 * @param targetLocalMinutes - Intended local delivery time, in minutes from midnight (8 AM = 480)
 * @param windowMinutes - How long after the target it stays deliverable
 * @param now - Instant to evaluate (defaults to current time)
 */
export function isWithinDeliveryWindow(
  timezoneOffsetMinutes: number,
  targetLocalMinutes: number,
  windowMinutes: number = DEFAULT_CATCH_UP_WINDOW_MINUTES,
  now: Date = new Date()
): boolean {
  const localMinutes = localMinutesFromMidnight(timezoneOffsetMinutes, now)
  const windowEnd = Math.min(targetLocalMinutes + windowMinutes, MINUTES_PER_DAY)
  return localMinutes >= targetLocalMinutes && localMinutes < windowEnd
}
