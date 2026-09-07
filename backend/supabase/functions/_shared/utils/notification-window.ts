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

/**
 * Minimum gap between two notifications of ANY category for the same user.
 *
 * The per-category windows deliberately overlap — around 10-11 AM local, daily
 * verse, recommended topic, memory verse reminder and streak lost can all be
 * eligible in the same hourly run, which would arrive as a burst of four. A
 * user who was notified within this many minutes is skipped and picked up by a
 * later run, still inside that category's own window, so nothing is lost —
 * it is just spread out.
 *
 * Set to an hour so at most one notification lands per hourly run.
 */
export const MIN_MINUTES_BETWEEN_NOTIFICATIONS = 60

/**
 * Notification types that participate in cross-category spacing.
 *
 * Only the locally-scheduled devotional senders should space each other out —
 * they are the ones with overlapping local-time delivery windows that could
 * otherwise burst. Fellowship and Discipler pushes are event-driven, are
 * logged to notification_logs for observability and dedup, but must NOT
 * suppress — or be suppressed by — a scheduled notification: a chatty
 * fellowship thread 20 minutes before the daily verse must never cause that
 * verse to be skipped, and the daily verse must never delay a fellowship
 * reply either.
 */
export const SCHEDULED_NOTIFICATION_TYPES_FOR_SPACING = [
  'daily_verse',
  'recommended_topic',
  'continue_learning',
  'streak_reminder',
  'streak_lost',
  'streak_milestone',
  'memory_verse_reminder',
  'memory_verse_overdue',
] as const

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

// ============================================================================
// Quiet Hours
// ============================================================================
// Event-driven pushes (a post, a comment, a reaction, a Discipler reply) fire
// the instant the event happens. Without this, a 3 AM reaction wakes the
// recipient up. The product rule: send when the event happens, unless that
// lands inside the recipient's night, in which case hold until their morning.

/** Local minutes-from-midnight at which the night starts (22:00). */
export const QUIET_HOURS_START_MINUTES = 22 * 60

/** Local minutes-from-midnight at which the night ends and held pushes go out (07:00). */
export const QUIET_HOURS_END_MINUTES = 7 * 60

/**
 * Whether the recipient's local clock is currently inside quiet hours.
 *
 * The window wraps midnight, so it is a union rather than a range: local time
 * at or after 22:00, OR before 07:00. 21:59 and 07:00 are both outside it.
 *
 * A null offset means we have never learned this user's timezone. Returning
 * false is deliberate and load-bearing: unknown must mean "send now", never
 * "guess UTC and hold" — holding a push on the wrong clock delays it by up to
 * nine hours for a user who was wide awake.
 *
 * @param offsetMinutes - User's UTC offset in minutes (IST = +330), or null if unknown
 * @param now - Instant to evaluate
 */
export function isQuietHours(offsetMinutes: number | null, now: Date): boolean {
  if (offsetMinutes === null || offsetMinutes === undefined || !Number.isFinite(offsetMinutes)) return false
  const localMinutes = localMinutesFromMidnight(offsetMinutes, now)
  return localMinutes >= QUIET_HOURS_START_MINUTES || localMinutes < QUIET_HOURS_END_MINUTES
}

/**
 * The next UTC instant at which the recipient's local clock reads
 * `targetLocalMinutes`.
 *
 * The returned instant is truncated to the exact target minute (zero seconds),
 * so a queued row's `not_before` reads as a clean 07:00 local rather than
 * inheriting the seconds of whatever event triggered it.
 *
 * When the recipient's local clock is already AT the target, the target is due
 * now, so `now` is returned rather than the same time tomorrow — a caller
 * asking for a time that has just arrived must not be pushed a day forward.
 * Once the target has passed today locally, it resolves to tomorrow.
 *
 * @param offsetMinutes - User's UTC offset in minutes (IST = +330)
 * @param targetLocalMinutes - Local time wanted, in minutes from midnight (07:00 = 420)
 * @param now - Instant to measure from
 */
export function nextLocalTimeUtc(
  offsetMinutes: number,
  targetLocalMinutes: number,
  now: Date
): Date {
  const localMinutes = localMinutesFromMidnight(offsetMinutes, now)
  const minutesAhead = localMinutes <= targetLocalMinutes
    ? targetLocalMinutes - localMinutes
    : MINUTES_PER_DAY - localMinutes + targetLocalMinutes

  // Drop the seconds already elapsed in the current minute so the result lands
  // exactly on the target minute boundary.
  const partialMinuteMs = now.getUTCSeconds() * 1000 + now.getUTCMilliseconds()
  const candidate = new Date(now.getTime() + minutesAhead * 60_000 - partialMinuteMs)

  // Truncation can pull the "already due" case (minutesAhead === 0) a few
  // seconds into the past; never hand back an instant before now.
  return candidate.getTime() < now.getTime() ? now : candidate
}
