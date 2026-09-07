import type { SupabaseClient } from '@supabase/supabase-js'
import { FCMService, logNotification } from '../fcm-service.ts'
import { DISCIPLER_USER_ID, type DisciplerReaction, type FellowshipDisciplerSettings } from '../utils/discipler.ts'
import { isQuietHours, nextLocalTimeUtc, QUIET_HOURS_END_MINUTES } from '../utils/notification-window.ts'
import type { NotificationType } from './notification-helper-service.ts'

export interface DisciplerFellowshipRow extends FellowshipDisciplerSettings {
  id: string
  name: string
  language: 'en' | 'hi' | 'ml'
  daily_post_allowed: boolean
  daily_post_on: boolean
}

export const DISCIPLER_SETTINGS_COLUMNS =
  'id, name, language, discipler_allowed, discipler_reply_mode, discipler_reply_scope, discipler_reply_delay_min, discipler_react_enabled, daily_post_allowed, daily_post_on'

export async function loadFellowshipDiscipler(db: SupabaseClient, fellowshipId: string): Promise<DisciplerFellowshipRow | null> {
  const { data, error } = await db.from('fellowships').select(DISCIPLER_SETTINGS_COLUMNS).eq('id', fellowshipId).maybeSingle()
  if (error) { console.error('[discipler] settings load error:', error); return null }
  return (data as DisciplerFellowshipRow | null) ?? null
}

export async function isDisciplerGloballyEnabled(db: SupabaseClient): Promise<boolean> {
  const { data } = await db.from('system_config').select('value').eq('key', 'discipler_global_enabled').maybeSingle()
  return data?.value === 'true'
}

export async function enqueueReply(db: SupabaseClient, args: {
  postId: string; commentId?: string | null; fellowshipId: string; trigger: 'mention' | 'question'; runAfter: string
}): Promise<void> {
  const { error } = await db.from('discipler_reply_queue').upsert({
    post_id: args.postId,
    comment_id: args.commentId ?? null,
    fellowship_id: args.fellowshipId,
    trigger: args.trigger,
    run_after: args.runAfter,
    status: 'pending',
  }, { onConflict: 'post_id,comment_id', ignoreDuplicates: true })
  if (error) console.error('[discipler] enqueue error (non-fatal):', error)
}

export async function reactAsDiscipler(db: SupabaseClient, args: {
  postId: string; fellowshipId: string; reaction: DisciplerReaction; currentCounts: Record<string, number>
}): Promise<Record<string, number>> {
  const { error: insertError } = await db.from('fellowship_reactions').insert({
    post_id: args.postId, fellowship_id: args.fellowshipId, user_id: DISCIPLER_USER_ID, reaction_type: args.reaction,
  })
  if (insertError) { console.error('[discipler] reaction insert error:', insertError); return args.currentCounts }
  const counts = { ...args.currentCounts }
  counts[args.reaction] = (counts[args.reaction] || 0) + 1
  const { error: updateError } = await db.from('fellowship_posts').update({ reaction_counts: counts }).eq('id', args.postId)
  if (updateError) console.error('[discipler] reaction count update error (non-fatal):', updateError)
  return counts
}

export async function recordActivity(db: SupabaseClient, args: {
  fellowshipId: string; kind: 'reply' | 'react' | 'draft' | 'daily_post'
  postId?: string | null; commentId?: string | null; reaction?: string | null; language?: string | null
  summary: string; pushNow: boolean
}): Promise<void> {
  const { error } = await db.from('discipler_activity').insert({
    fellowship_id: args.fellowshipId, kind: args.kind, post_id: args.postId ?? null, comment_id: args.commentId ?? null,
    reaction: args.reaction ?? null, language: args.language ?? null, summary: args.summary.slice(0, 200),
    pushed_at: args.pushNow ? new Date().toISOString() : null,
  })
  if (error) console.error('[discipler] activity insert error (non-fatal):', error)
}

export async function pushUsers(db: SupabaseClient, userIds: string[], notification: { title: string; body: string }, data: Record<string, string>): Promise<void> {
  if (userIds.length === 0) return
  try {
    const { data: tokenRows } = await db.from('user_notification_tokens').select('fcm_token').in('user_id', userIds)
    const tokens = (tokenRows ?? []).map((r: { fcm_token: string }) => r.fcm_token).filter(Boolean)
    if (tokens.length === 0) return
    await new FCMService().sendBatchNotifications(tokens, notification, data)
  } catch (err) {
    console.error('[discipler] push error (non-fatal):', err)
  }
}

export async function pushMentors(db: SupabaseClient, fellowshipId: string, notification: { title: string; body: string }, data: Record<string, string>, opts: { excludeUserId?: string; respectMute?: boolean } = {}): Promise<void> {
  try {
    const { data: rows } = await db.rpc('fellowship_mentor_ids', { p_fellowship_id: fellowshipId })
    const ids = ((rows ?? []) as { user_id: string; discipler_activity_push: boolean }[])
      .filter((r) => !opts.respectMute || r.discipler_activity_push)
      .map((r) => r.user_id)
      .filter((id) => id !== opts.excludeUserId)
    await pushUsers(db, ids, notification, data)
  } catch (err) {
    console.error('[discipler] pushMentors error (non-fatal):', err)
  }
}

// ============================================================================
// Quiet-hours aware delivery
// ============================================================================

/** Options for {@link deliverOrQueue}. */
/// Maps a notification type to the `user_notification_preferences` column that
/// switches it off. Every type in the notification_logs CHECK constraint has
/// one; a type missing here is simply never filtered.
const PREFERENCE_COLUMN: Record<string, string> = {
  daily_verse: 'daily_verse_enabled',
  recommended_topic: 'recommended_topic_enabled',
  continue_learning: 'continue_learning_enabled',
  streak_reminder: 'streak_reminder_enabled',
  streak_milestone: 'streak_milestone_enabled',
  streak_lost: 'streak_lost_enabled',
  memory_verse_reminder: 'memory_verse_reminder_enabled',
  memory_verse_overdue: 'memory_verse_overdue_enabled',
  achievement_unlocked: 'achievement_unlocked_enabled',
  meeting_invite: 'meeting_invite_enabled',
  fellowship_daily_post: 'fellowship_daily_post_enabled',
  fellowship_new_post: 'fellowship_new_post_enabled',
  fellowship_new_comment: 'fellowship_new_comment_enabled',
  fellowship_reaction: 'fellowship_reaction_enabled',
  fellowship_discipler_reply: 'fellowship_discipler_reply_enabled',
  fellowship_discipler_activity: 'fellowship_discipler_activity_enabled',
  fellowship_meeting: 'fellowship_meeting_enabled',
  fellowship_meeting_reminder: 'fellowship_meeting_reminder_enabled',
  fellowship_meeting_cancelled: 'fellowship_meeting_cancelled_enabled',
  fellowship_meeting_invite: 'fellowship_meeting_invite_enabled',
}

export interface DeliverOptions {
  /**
   * The notification's type, used both as the queue row's `kind` and as the
   * `notification_logs.notification_type`. Must be a value the
   * notification_logs CHECK constraint accepts (see
   * notification-type-constraint.test.ts).
   */
  kind: NotificationType
  /**
   * Time-critical notifications that are worthless once delayed — a meeting
   * reminder for a meeting that has already started, a cancellation delivered
   * after the slot, an invite to a meeting happening tonight. These bypass
   * quiet hours entirely.
   */
  urgent?: boolean
}

/** What one {@link deliverOrQueue} call did, for the caller's logs. */
export interface DeliverResult {
  sentTo: number
  queuedTo: number
}

/**
 * Send a push now, or hold it until the recipient's morning.
 *
 * This is the single entry point every event-driven push goes through, so the
 * quiet-hours rule lives in exactly one place rather than being re-derived per
 * sender.
 *
 * The decision is made PER RECIPIENT, not per call: one new post can be
 * daytime for the member in Bengaluru and 2 AM for the member in London, so
 * the same call sends to the first and queues for the second.
 *
 * A recipient is sent to immediately when ANY of these hold:
 *   - the notification is urgent
 *   - they have no user_notification_preferences row
 *   - their timezone_offset_minutes is NULL (unknown — never guess UTC)
 *   - their local time is outside 22:00–07:00
 *
 * Otherwise a notification_push_queue row is written with `not_before` set to
 * the next instant their local clock reads 07:00, and the flush route delivers
 * it then.
 *
 * Failure of the preference lookup falls through to sending everything now:
 * a delayed push is a worse outcome than a push that arrives at a slightly
 * inconvenient hour, and silently dropping is never acceptable.
 */
export async function deliverOrQueue(
  db: SupabaseClient,
  userIds: string[],
  notification: { title: string; body: string },
  data: Record<string, string>,
  opts: DeliverOptions,
): Promise<DeliverResult> {
  const recipients = [...new Set(userIds)].filter(Boolean)
  if (recipients.length === 0) return { sentTo: 0, queuedTo: 0 }

  const now = new Date()
  let sendNow: string[] = recipients
  // Recipients held for the morning, paired with the offset that decided it —
  // the offset is needed again to compute each row's own not_before.
  let toQueue: Array<{ userId: string; offsetMinutes: number }> = []

  // One query for every recipient's preferences — never N+1 inside the loop.
  // It answers both questions at once: did this person switch this type off,
  // and what is their local time.
  const prefColumn = PREFERENCE_COLUMN[opts.kind]
  const columns = prefColumn
    ? `user_id, timezone_offset_minutes, ${prefColumn}`
    : 'user_id, timezone_offset_minutes'

  const { data: prefRows, error } = await db
    .from('user_notification_preferences')
    .select(columns)
    .in('user_id', recipients)

  if (error) {
    // Fail open. A missed push is a worse outcome than one that arrives at an
    // awkward hour, and silently dropping is never acceptable.
    console.error('[deliverOrQueue] Preference lookup failed, sending all now (non-fatal):', error.message)
  } else {
    const rows = (prefRows ?? []) as unknown as Array<Record<string, unknown>>
    const byUser = new Map(rows.map((r) => [r.user_id as string, r]))

    // Opt-out applies even to urgent notifications: the user turned this type
    // off deliberately. A missing row means "never configured" — send.
    const wanted = recipients.filter((id) => {
      if (!prefColumn) return true
      const row = byUser.get(id)
      if (!row) return true
      return row[prefColumn] !== false
    })

    if (opts.urgent) {
      sendNow = wanted
    } else {
      sendNow = []
      toQueue = []
      for (const id of wanted) {
        // A missing row and a row with a NULL offset both mean "unknown", and
        // unknown means send now.
        const offset = (byUser.get(id)?.timezone_offset_minutes as number | null) ?? null
        if (offset !== null && isQuietHours(offset, now)) toQueue.push({ userId: id, offsetMinutes: offset })
        else sendNow.push(id)
      }
    }
  }

  if (toQueue.length > 0) {
    const rows = toQueue.map(({ userId, offsetMinutes }) => ({
      user_id: userId,
      kind: opts.kind,
      title: notification.title,
      body: notification.body,
      data,
      not_before: nextLocalTimeUtc(offsetMinutes, QUIET_HOURS_END_MINUTES, now).toISOString(),
    }))
    const { error } = await db.from('notification_push_queue').insert(rows)
    if (error) {
      // Never drop: if the hold area rejected the rows, deliver now rather than
      // losing the notification entirely.
      console.error('[deliverOrQueue] Queue insert failed, sending now instead (non-fatal):', error.message)
      sendNow = [...sendNow, ...toQueue.map((r) => r.userId)]
      toQueue = []
    }
  }

  if (sendNow.length > 0) {
    // Concurrently, not sequentially: an FCM round-trip to Google takes far
    // longer than the log insert, and these run in a fire-and-forget context
    // whose isolate can be torn down once the response has been written.
    // Chaining the log behind the send meant it never happened.
    await Promise.all([
      pushUsers(db, sendNow, notification, data),
      logPushes(sendNow, notification, opts.kind, 'sent'),
    ])
  }
  if (toQueue.length > 0) {
    console.log(`[deliverOrQueue] ${opts.kind}: queued for ${toQueue.length} recipient(s) until their 07:00 local`)
  }

  return { sentTo: sendNow.length, queuedTo: toQueue.length }
}

/**
 * Send a single already-queued row.
 *
 * Shared with the flush route so a released push logs exactly like an
 * immediate one. Throws when FCM rejected every token, so the flush route can
 * count the attempt and retry; a recipient with no registered device is not a
 * failure — retrying would not conjure a token.
 */
export async function deliverQueuedRow(
  db: SupabaseClient,
  row: { id: string; user_id: string; kind: string; title: string; body: string; data: Record<string, string> },
): Promise<void> {
  const { data: tokenRows } = await db.from('user_notification_tokens').select('fcm_token').eq('user_id', row.user_id)
  const tokens = (tokenRows ?? []).map((r: { fcm_token: string }) => r.fcm_token).filter(Boolean)
  if (tokens.length === 0) {
    // No device to reach is not a failure — the row is done either way, and
    // retrying it three times would not conjure a token.
    return
  }
  const result = await new FCMService().sendBatchNotifications(
    tokens,
    { title: row.title, body: row.body },
    row.data ?? {},
  )
  if (result.successCount === 0 && result.failureCount > 0) {
    throw new Error(`FCM rejected all ${result.failureCount} token(s)`)
  }
  await logPushes([row.user_id], { title: row.title, body: row.body }, row.kind as NotificationType, 'sent')
}

/**
 * Record pushes in notification_logs.
 *
 * Fellowship pushes historically never logged, which left them out of both the
 * audit trail and the cross-category spacing rule that keeps a user from being
 * hit by several notifications at once. Best-effort by design: logNotification
 * already swallows its own errors, and this wrapper swallows anything else, so
 * a logging problem can never fail a push that was already delivered.
 */
async function logPushes(
  userIds: string[],
  notification: { title: string; body: string },
  kind: NotificationType,
  status: 'sent' | 'failed',
): Promise<void> {
  const url = Deno.env.get('SUPABASE_URL')
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!url || !key) return
  try {
    await Promise.all(userIds.map((userId) =>
      logNotification(url, key, {
        userId,
        notificationType: kind,
        title: notification.title,
        body: notification.body,
        language: 'en',
        deliveryStatus: status,
      })
    ))
  } catch (err) {
    console.error('[deliverOrQueue] Notification logging failed (non-fatal):', err)
  }
}

/**
 * Quiet-hours aware counterpart to {@link pushMentors}.
 *
 * Resolves the fellowship's mentors (honouring their activity-push mute) and
 * hands them to {@link deliverOrQueue}, so a mentor asleep in another timezone
 * gets the notification in the morning while their co-mentor at their desk
 * gets it now.
 */
export async function pushMentorsOrQueue(
  db: SupabaseClient,
  fellowshipId: string,
  notification: { title: string; body: string },
  data: Record<string, string>,
  opts: DeliverOptions & { excludeUserId?: string; respectMute?: boolean },
): Promise<DeliverResult> {
  try {
    const { data: rows } = await db.rpc('fellowship_mentor_ids', { p_fellowship_id: fellowshipId })
    const ids = ((rows ?? []) as { user_id: string; discipler_activity_push: boolean }[])
      .filter((r) => !opts.respectMute || r.discipler_activity_push)
      .map((r) => r.user_id)
      .filter((id) => id !== opts.excludeUserId)
    return await deliverOrQueue(db, ids, notification, data, { kind: opts.kind, urgent: opts.urgent })
  } catch (err) {
    console.error('[discipler] pushMentorsOrQueue error (non-fatal):', err)
    return { sentTo: 0, queuedTo: 0 }
  }
}
