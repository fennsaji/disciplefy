/**
 * fellowship-meetings-reminder  (cron — called every 5 minutes by GitHub Actions)
 *
 * Picks unsent meeting_reminders rows whose remind_at <= now(),
 * sends FCM push notifications to all active members, then stamps sent_at.
 *
 * Two reminders are created per meeting by fellowship-meetings-create:
 *   • 1 hour before     → "Meeting in 1 hour"
 *   • 10 minutes before → "Meeting in 10 minutes"
 *
 * Configured in config.toml:
 *   [functions.fellowship-meetings-reminder]
 *   verify_jwt = false   (auth handled via X-Cron-Secret header)
 *
 * Scheduled via GitHub Actions workflow: meeting-reminders.yml  cron: every 5 min
 */

import { serve } from 'std/http/server.ts'
import { getServiceContainer } from '../_shared/core/services.ts'
import { FCMService } from '../_shared/fcm-service.ts'

serve(async (req: Request): Promise<Response> => {
  // Verify the request comes from our GitHub Actions cron job.
  const cronSecret = Deno.env.get('CRON_SECRET')
  if (cronSecret) {
    const incoming = req.headers.get('x-cron-secret')
    if (incoming !== cronSecret) {
      return new Response('Unauthorized', { status: 401 })
    }
  }

  const services = await getServiceContainer()
  const db = services.supabaseServiceClient

  // Fetch all unsent reminders that are due right now.
  const { data: reminders, error } = await db
    .from('meeting_reminders')
    .select(`
      id,
      offset_label,
      meeting_id,
      fellowship_meetings (
        fellowship_id,
        title,
        starts_at,
        is_cancelled
      )
    `)
    .lte('remind_at', new Date().toISOString())
    .is('sent_at', null)

  if (error) {
    console.error('[fellowship-meetings-reminder] Query error:', error)
    return new Response('error', { status: 500 })
  }

  if (!reminders || reminders.length === 0) {
    return new Response('ok — no reminders due', { status: 200 })
  }

  const fcm = new FCMService()
  let sent = 0

  for (const reminder of reminders) {
    const meeting = reminder.fellowship_meetings as unknown as {
      fellowship_id: string
      title: string
      starts_at: string
      is_cancelled: boolean
    } | null

    // Skip if the meeting was cancelled after the reminder was scheduled.
    if (!meeting || meeting.is_cancelled) {
      await db
        .from('meeting_reminders')
        .update({ sent_at: new Date().toISOString() })
        .eq('id', reminder.id)
      continue
    }

    // Build notification copy based on how far away the meeting is.
    const isTenMinutes = reminder.offset_label === '10 minutes'
    const notif = isTenMinutes
      ? { title: '📹 Meeting in 10 minutes', body: `"${meeting.title}" is about to begin` }
      : { title: '⏰ Meeting in 1 hour', body: `"${meeting.title}" starts in 1 hour` }

    // Fetch FCM tokens for all active fellowship members.
    const { data: memberRows } = await db
      .from('fellowship_members')
      .select('user_id')
      .eq('fellowship_id', meeting.fellowship_id)
      .eq('is_active', true)

    const memberIds = (memberRows ?? []).map((m: { user_id: string }) => m.user_id)

    if (memberIds.length > 0) {
      const { data: tokenRows } = await db
        .from('user_notification_tokens')
        .select('fcm_token')
        .in('user_id', memberIds)

      const tokens = (tokenRows ?? [])
        .map((r: { fcm_token: string }) => r.fcm_token)
        .filter(Boolean)

      if (tokens.length > 0) {
        try {
          await fcm.sendBatchNotifications(tokens, notif, {
            type: 'fellowship_meeting_reminder',
            fellowship_id: meeting.fellowship_id,
            meeting_id: reminder.meeting_id,
            offset_label: reminder.offset_label,
          })
        } catch (fcmErr) {
          console.error('[fellowship-meetings-reminder] FCM error for meeting', reminder.meeting_id, fcmErr)
        }
      }
    }

    // Stamp as sent regardless of FCM outcome — prevents duplicate sends.
    await db
      .from('meeting_reminders')
      .update({ sent_at: new Date().toISOString() })
      .eq('id', reminder.id)

    sent++
  }

  console.log(`[fellowship-meetings-reminder] Sent ${sent}/${reminders.length} reminders`)
  return new Response(`ok — sent ${sent}`, { status: 200 })
})
