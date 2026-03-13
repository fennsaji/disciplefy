/**
 * fellowship-meetings  (merged)
 * Routes:
 *   GET  /fellowship-meetings?fellowship_id=UUID  → list upcoming meetings (member)
 *   POST /fellowship-meetings                      → create meeting (mentor)
 *   POST /fellowship-meetings/cancel               → cancel meeting (mentor)
 *   POST /fellowship-meetings/reminder             → cron — send FCM reminders (CRON_SECRET auth)
 *
 * Note: verify_jwt = false in config.toml so the cron route works without a user JWT.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import { createCalendarEvent, cancelCalendarEvent, refreshGoogleAccessToken } from '../_shared/utils/google-calendar.ts'
import { FCMService } from '../_shared/fcm-service.ts'

// ---------------------------------------------------------------------------
// List meetings  GET /fellowship-meetings?fellowship_id=UUID
// ---------------------------------------------------------------------------

async function handleListMeetings(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  const url = new URL(req.url)
  const fellowshipId = url.searchParams.get('fellowship_id')
  if (!fellowshipId) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)

  const rawLimit = parseInt(url.searchParams.get('limit') || '20', 10)
  const limit = Number.isNaN(rawLimit) || rawLimit < 1 ? 20 : Math.min(rawLimit, 50)

  const db = services.supabaseServiceClient

  const { data: isMember, error: rpcError } = await db.rpc('is_fellowship_member', {
    p_fellowship_id: fellowshipId, p_user_id: user.id
  })
  if (rpcError) throw new AppError('DATABASE_ERROR', 'Failed to verify membership', 500)
  if (!isMember) throw new AppError('PERMISSION_DENIED', 'Must be a fellowship member', 403)

  const now = new Date().toISOString()
  const { data: meetings, error } = await db
    .from('fellowship_meetings')
    .select('id, fellowship_id, created_by, title, description, starts_at, ends_at, recurrence, meet_link, created_at')
    .eq('fellowship_id', fellowshipId)
    .eq('is_cancelled', false)
    .gte('starts_at', now)
    .order('starts_at', { ascending: true })
    .limit(limit)

  if (error) {
    console.error('[fellowship-meetings/list] Query error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch meetings', 500)
  }

  return new Response(
    JSON.stringify({ success: true, data: meetings ?? [] }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Create meeting  POST /fellowship-meetings
// ---------------------------------------------------------------------------

interface CreateMeetingRequest {
  fellowship_id: string
  title: string
  description?: string
  starts_at: string
  duration_minutes: number
  time_zone: string
  recurrence?: 'daily' | 'weekly' | 'monthly' | null
  location?: string
  google_access_token?: string
  google_refresh_token?: string
}

function escHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

function buildMeetingInviteEmail(opts: {
  title: string; description?: string | null; dateStr: string; timeStr: string;
  durationLabel: string; meetLink: string; addToCalendarUrl: string; recurrence?: string | null
}): string {
  const recurrenceBadge = opts.recurrence
    ? `<span style="display:inline-block;background:#4338ca22;color:#6366f1;font-size:11px;font-weight:700;padding:2px 10px;border-radius:20px;letter-spacing:0.5px;margin-left:10px;text-transform:capitalize;">${opts.recurrence}</span>`
    : ''
  return `<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#0f0f1a;font-family:'Inter',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#0f0f1a;padding:32px 16px;">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;">
        <tr><td style="padding-bottom:24px;text-align:center;">
          <span style="font-size:22px;font-weight:800;color:#fff;letter-spacing:-0.5px;">Disciplefy</span>
        </td></tr>
        <tr><td style="background:#1a1a2e;border-radius:20px;overflow:hidden;border:1px solid #2a2a40;">
          <div style="height:4px;background:linear-gradient(90deg,#4f46e5,#6366f1);"></div>
          <table width="100%" cellpadding="0" cellspacing="0" style="padding:28px 28px 24px;">
            <tr><td style="padding-bottom:20px;">
              <table cellpadding="0" cellspacing="0"><tr>
                <td style="background:linear-gradient(135deg,#4f46e5,#6366f1);width:48px;height:48px;border-radius:14px;text-align:center;vertical-align:middle;">
                  <span style="font-size:22px;line-height:48px;">📹</span>
                </td>
                <td style="padding-left:14px;vertical-align:middle;">
                  <div style="font-size:11px;font-weight:600;color:#6366f1;letter-spacing:1px;text-transform:uppercase;margin-bottom:4px;">Fellowship Meeting</div>
                  <div style="font-size:20px;font-weight:800;color:#fff;line-height:1.2;">${escHtml(opts.title)}${recurrenceBadge}</div>
                </td>
              </tr></table>
            </td></tr>
            ${opts.description ? `<tr><td style="padding-bottom:20px;"><p style="margin:0;font-size:14px;color:#a0a0c0;line-height:1.6;">${escHtml(opts.description)}</p></td></tr>` : ''}
            <tr><td style="padding-bottom:24px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#12122a;border-radius:12px;overflow:hidden;">
                <tr><td style="padding:14px 18px;border-bottom:1px solid #2a2a40;"><span style="font-size:12px;color:#6366f1;margin-right:8px;">📅</span><span style="font-size:13px;font-weight:600;color:#e0e0f0;">${opts.dateStr}</span></td></tr>
                <tr><td style="padding:14px 18px;border-bottom:1px solid #2a2a40;"><span style="font-size:12px;color:#6366f1;margin-right:8px;">🕐</span><span style="font-size:13px;font-weight:600;color:#e0e0f0;">${opts.timeStr}</span><span style="font-size:12px;color:#6060a0;margin-left:10px;">· ${opts.durationLabel}</span></td></tr>
                <tr><td style="padding:14px 18px;"><span style="font-size:12px;color:#6366f1;margin-right:8px;">🔗</span><a href="${opts.meetLink}" style="font-size:13px;font-weight:600;color:#6366f1;text-decoration:none;">${opts.meetLink}</a></td></tr>
              </table>
            </td></tr>
            <tr><td style="padding-bottom:14px;"><a href="${opts.meetLink}" style="display:block;background:#ffeec0;color:#1a1a2e;text-align:center;padding:14px 24px;border-radius:12px;font-size:15px;font-weight:800;text-decoration:none;">▶ Join Meeting</a></td></tr>
            <tr><td><a href="${opts.addToCalendarUrl}" style="display:block;background:transparent;color:#6366f1;text-align:center;padding:12px 24px;border-radius:12px;font-size:14px;font-weight:700;text-decoration:none;border:1.5px solid #6366f1;">📆 Add to Google Calendar</a></td></tr>
          </table>
        </td></tr>
        <tr><td style="padding-top:20px;text-align:center;"><p style="margin:0;font-size:12px;color:#404060;">You received this because you're a member of this fellowship on <span style="color:#6366f1;">Disciplefy</span>.</p></td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`
}

async function handleCreateMeeting(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: CreateMeetingRequest
  try { body = await req.json() as CreateMeetingRequest } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }

  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.title?.trim()) throw new AppError('VALIDATION_ERROR', 'title is required', 400)
  if (body.title.trim().length > 100) throw new AppError('VALIDATION_ERROR', 'title must be 100 characters or fewer', 400)
  if (!body.starts_at) throw new AppError('VALIDATION_ERROR', 'starts_at is required', 400)
  if (!body.time_zone) throw new AppError('VALIDATION_ERROR', 'time_zone is required', 400)

  const startsAt = new Date(body.starts_at)
  if (isNaN(startsAt.getTime())) throw new AppError('VALIDATION_ERROR', 'starts_at must be a valid ISO-8601 date', 400)
  if (startsAt <= new Date()) throw new AppError('VALIDATION_ERROR', 'starts_at must be in the future', 400)

  if (body.duration_minutes === undefined || body.duration_minutes === null) throw new AppError('VALIDATION_ERROR', 'duration_minutes is required', 400)
  const durationMinutes = body.duration_minutes
  if (![30, 60, 90, 120].includes(durationMinutes)) throw new AppError('VALIDATION_ERROR', 'duration_minutes must be 30, 60, 90, or 120', 400)
  if (body.recurrence !== undefined && body.recurrence !== null && !['daily', 'weekly', 'monthly'].includes(body.recurrence)) {
    throw new AppError('VALIDATION_ERROR', 'recurrence must be daily, weekly, monthly, or null', 400)
  }

  const db = services.supabaseServiceClient

  const { data: isMentor, error: mentorError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id, p_user_id: user.id
  })
  if (mentorError) throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Only the fellowship mentor can schedule meetings', 403)

  const endsAt = new Date(startsAt.getTime() + durationMinutes * 60 * 1000)

  const { data: memberRows } = await db.from('fellowship_members').select('user_id')
    .eq('fellowship_id', body.fellowship_id).eq('is_active', true)
  const memberIds = (memberRows ?? []).map((m: { user_id: string }) => m.user_id)

  let attendeeEmails: string[] = []
  if (body.google_access_token && memberIds.length > 0) {
    const emailEntries = await Promise.all(
      memberIds.map(async (uid: string): Promise<string | null> => {
        try { const { data } = await services.supabaseServiceClient.auth.admin.getUserById(uid); return data?.user?.email ?? null } catch { return null }
      })
    )
    attendeeEmails = emailEntries.filter((e): e is string => e !== null)
  }

  const isInPerson = !!body.location?.trim()
  let calendarResult: { eventId: string; meetLink: string; calendarType: 'service_account' | 'user_primary' } =
    { eventId: '', meetLink: '', calendarType: 'service_account' }

  if (!isInPerson) {
    try {
      calendarResult = await createCalendarEvent({
        title: body.title.trim(), description: body.description?.trim() ?? null,
        startsAt: startsAt.toISOString(), endsAt: endsAt.toISOString(),
        timeZone: body.time_zone, recurrence: body.recurrence ?? null,
        attendeeEmails, userAccessToken: body.google_access_token, userRefreshToken: body.google_refresh_token,
      })
    } catch (err) {
      console.error('[fellowship-meetings/create] Google Calendar error (non-fatal):', err)
    }
  }

  const { data: meeting, error: insertError } = await db
    .from('fellowship_meetings')
    .insert({
      fellowship_id: body.fellowship_id, created_by: user.id,
      title: body.title.trim(), description: body.description?.trim() ?? null,
      starts_at: startsAt.toISOString(), ends_at: endsAt.toISOString(),
      recurrence: body.recurrence ?? null, location: body.location?.trim() ?? null,
      meet_link: calendarResult.meetLink, calendar_event_id: calendarResult.eventId,
      calendar_type: calendarResult.calendarType,
      google_refresh_token: body.google_refresh_token ?? null,
    })
    .select().single()

  if (insertError) {
    console.error('[fellowship-meetings/create] DB insert error:', insertError)
    if (calendarResult.eventId) {
      cancelCalendarEvent(calendarResult.eventId, calendarResult.calendarType).catch(err =>
        console.error('[fellowship-meetings/create] Orphan cleanup failed:', calendarResult.eventId, err)
      )
    }
    throw new AppError('DATABASE_ERROR', 'Failed to save meeting', 500)
  }

  ;(async () => {
    try {
      await db.from('meeting_reminders').insert([
        { meeting_id: meeting.id, remind_at: new Date(startsAt.getTime() - 60 * 60 * 1000).toISOString(), offset_label: '1 hour' },
        { meeting_id: meeting.id, remind_at: new Date(startsAt.getTime() - 10 * 60 * 1000).toISOString(), offset_label: '10 minutes' },
      ])
    } catch (err) { console.error('[fellowship-meetings/create] Failed to schedule reminders (non-fatal):', err) }
  })()

  ;(async () => {
    try {
      const { data: members } = await db.from('fellowship_members').select('user_id')
        .eq('fellowship_id', body.fellowship_id).eq('is_active', true)
      const allMemberIds = (members ?? []).map((m: { user_id: string }) => m.user_id)
      if (allMemberIds.length === 0) return

      const startsAtDate = new Date(meeting.starts_at)
      const endsAtDate = new Date(meeting.ends_at)
      const dateStr = startsAtDate.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })
      const timeStr = startsAtDate.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })
      const dur = Math.round((endsAtDate.getTime() - startsAtDate.getTime()) / 60000)
      const durationLabel = dur < 60 ? `${dur} min` : dur % 60 === 0 ? `${dur / 60} hr` : `${Math.floor(dur / 60)} hr ${dur % 60} min`
      const gcalDateFmt = (d: Date) => d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')
      const gcalDetails = encodeURIComponent([meeting.description, `Join meeting: ${meeting.meet_link}`].filter(Boolean).join('\n\n'))
      const addToCalendarUrl = `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${encodeURIComponent(meeting.title)}&dates=${gcalDateFmt(startsAtDate)}/${gcalDateFmt(endsAtDate)}&details=${gcalDetails}&location=${encodeURIComponent(meeting.meet_link)}`

      try {
        const { data: tokenRows } = await db.from('user_notification_tokens').select('fcm_token').in('user_id', allMemberIds)
        const tokens = (tokenRows ?? []).map((r: { fcm_token: string }) => r.fcm_token).filter(Boolean)
        if (tokens.length > 0) {
          const fcm = new FCMService()
          await fcm.sendBatchNotifications(tokens,
            { title: `📅 New Meeting: ${meeting.title}`, body: `${dateStr} at ${timeStr} · ${durationLabel}` },
            { type: 'fellowship_meeting', fellowship_id: body.fellowship_id, meeting_id: meeting.id, meet_link: meeting.meet_link }
          )
        }
      } catch (fcmErr) { console.error('[fellowship-meetings/create] FCM error (non-fatal):', fcmErr) }

      const resendApiKey = Deno.env.get('RESEND_API_KEY')
      if (!resendApiKey) { console.warn('[fellowship-meetings/create] RESEND_API_KEY not set'); return }

      const emailEntries = await Promise.all(
        allMemberIds.map(async (userId: string): Promise<string | null> => {
          try { const { data } = await services.supabaseServiceClient.auth.admin.getUserById(userId); return data?.user?.email ?? null } catch { return null }
        })
      )
      const emails = emailEntries.filter((e): e is string => e !== null)
      if (emails.length === 0) return

      const html = buildMeetingInviteEmail({ title: meeting.title, description: meeting.description, dateStr, timeStr, durationLabel, meetLink: meeting.meet_link, addToCalendarUrl, recurrence: meeting.recurrence })
      await Promise.allSettled(
        emails.map(email =>
          fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: { Authorization: `Bearer ${resendApiKey}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ from: 'Disciplefy <noreply@disciplefy.in>', to: [email], subject: `📅 New Fellowship Meeting: ${meeting.title}`, html }),
          }).then(r => { if (!r.ok) r.text().then(t => console.error(`[fellowship-meetings/create] Resend error for ${email}:`, t)) })
        )
      )
    } catch (err) { console.error('[fellowship-meetings/create] Notification error (non-fatal):', err) }
  })()

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: meeting.id, fellowship_id: meeting.fellowship_id, title: meeting.title,
        description: meeting.description, starts_at: meeting.starts_at, ends_at: meeting.ends_at,
        recurrence: meeting.recurrence, location: meeting.location ?? null, meet_link: meeting.meet_link,
        created_by: meeting.created_by, created_at: meeting.created_at,
      }
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Cancel meeting  POST /fellowship-meetings/cancel
// ---------------------------------------------------------------------------

interface CancelMeetingRequest {
  meeting_id: string
  google_access_token?: string
}

async function handleCancelMeeting(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: CancelMeetingRequest
  try { body = await req.json() as CancelMeetingRequest } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.meeting_id) throw new AppError('VALIDATION_ERROR', 'meeting_id is required', 400)

  const db = services.supabaseServiceClient

  const { data: meeting, error: fetchError } = await db
    .from('fellowship_meetings').select('id, fellowship_id, calendar_event_id, calendar_type, is_cancelled, created_by')
    .eq('id', body.meeting_id).maybeSingle()

  if (fetchError) throw new AppError('DATABASE_ERROR', 'Failed to fetch meeting', 500)
  if (!meeting) throw new AppError('NOT_FOUND', 'Meeting not found', 404)
  if (meeting.is_cancelled) throw new AppError('CONFLICT', 'Meeting is already cancelled', 409)

  const { data: isMentor, error: mentorError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: meeting.fellowship_id, p_user_id: user.id
  })
  if (mentorError) throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Only the fellowship mentor can cancel meetings', 403)

  if (meeting.calendar_event_id) {
    try {
      await cancelCalendarEvent(meeting.calendar_event_id, meeting.calendar_type ?? 'service_account', body.google_access_token)
    } catch (err) {
      console.error('[fellowship-meetings/cancel] Google Calendar error (non-blocking):', err)
    }
  } else {
    console.warn('[fellowship-meetings/cancel] No calendar_event_id on meeting:', body.meeting_id)
  }

  const { error: updateError } = await db.from('fellowship_meetings').update({ is_cancelled: true }).eq('id', body.meeting_id)
  if (updateError) {
    console.error('[fellowship-meetings/cancel] DB update error:', updateError)
    throw new AppError('DATABASE_ERROR', 'Failed to cancel meeting', 500)
  }

  return new Response(JSON.stringify({ success: true, message: 'Meeting cancelled' }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

// ---------------------------------------------------------------------------
// Meeting reminder cron  POST /fellowship-meetings/reminder
// Authenticated via X-Cron-Secret header (no user JWT required)
// ---------------------------------------------------------------------------

async function handleReminder(req: Request, services: ServiceContainer): Promise<Response> {
  const cronSecret = Deno.env.get('CRON_SECRET')
  if (cronSecret) {
    const incoming = req.headers.get('x-cron-secret')
    if (incoming !== cronSecret) {
      return new Response('Unauthorized', { status: 401 })
    }
  }

  const db = services.supabaseServiceClient

  const { data: reminders, error } = await db
    .from('meeting_reminders')
    .select(`id, offset_label, meeting_id, fellowship_meetings ( fellowship_id, title, starts_at, is_cancelled )`)
    .lte('remind_at', new Date().toISOString())
    .is('sent_at', null)

  if (error) {
    console.error('[fellowship-meetings/reminder] Query error:', error)
    return new Response('error', { status: 500 })
  }

  if (!reminders || reminders.length === 0) {
    return new Response('ok — no reminders due', { status: 200 })
  }

  const fcm = new FCMService()
  let sent = 0

  for (const reminder of reminders) {
    const meeting = reminder.fellowship_meetings as unknown as {
      fellowship_id: string; title: string; starts_at: string; is_cancelled: boolean
    } | null

    if (!meeting || meeting.is_cancelled) {
      await db.from('meeting_reminders').update({ sent_at: new Date().toISOString() }).eq('id', reminder.id)
      continue
    }

    const isTenMinutes = reminder.offset_label === '10 minutes'
    const notif = isTenMinutes
      ? { title: '📹 Meeting in 10 minutes', body: `"${meeting.title}" is about to begin` }
      : { title: '⏰ Meeting in 1 hour', body: `"${meeting.title}" starts in 1 hour` }

    const { data: memberRows } = await db.from('fellowship_members').select('user_id')
      .eq('fellowship_id', meeting.fellowship_id).eq('is_active', true)
    const memberIds = (memberRows ?? []).map((m: { user_id: string }) => m.user_id)

    if (memberIds.length > 0) {
      const { data: tokenRows } = await db.from('user_notification_tokens').select('fcm_token').in('user_id', memberIds)
      const tokens = (tokenRows ?? []).map((r: { fcm_token: string }) => r.fcm_token).filter(Boolean)
      if (tokens.length > 0) {
        try {
          await fcm.sendBatchNotifications(tokens, notif, {
            type: 'fellowship_meeting_reminder',
            fellowship_id: meeting.fellowship_id,
            meeting_id: reminder.meeting_id,
            offset_label: reminder.offset_label,
          })
        } catch (fcmErr) {
          console.error('[fellowship-meetings/reminder] FCM error for meeting', reminder.meeting_id, fcmErr)
        }
      }
    }

    await db.from('meeting_reminders').update({ sent_at: new Date().toISOString() }).eq('id', reminder.id)
    sent++
  }

  console.log(`[fellowship-meetings/reminder] Sent ${sent}/${reminders.length} reminders`)
  return new Response(`ok — sent ${sent}`, { status: 200 })
}

// ---------------------------------------------------------------------------
// Invite new member to upcoming meetings  POST /fellowship-meetings/invite-member
// Internal service-role only — called fire-and-forget from join handlers.
// Auth: checks Authorization header against SUPABASE_SERVICE_ROLE_KEY.
// ---------------------------------------------------------------------------

interface InviteMemberRequest {
  fellowshipId: string
  memberId: string
}

async function handleInviteMember(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (!authHeader || authHeader !== `Bearer ${serviceRoleKey}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  let body: InviteMemberRequest
  try {
    body = await req.json() as InviteMemberRequest
  } catch {
    return new Response('Bad Request', { status: 400 })
  }

  const { fellowshipId, memberId } = body
  if (!fellowshipId || !memberId) {
    return new Response('fellowshipId and memberId required', { status: 400 })
  }

  const db = services.supabaseServiceClient

  // Rate limit: skip if member already received a meeting_invite in last 24h
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const { data: recentLog } = await db
    .from('notification_logs')
    .select('id')
    .eq('user_id', memberId)
    .eq('notification_type', 'meeting_invite')
    .gte('created_at', since)
    .maybeSingle()

  if (recentLog) {
    console.log(`[invite-member] Skipping ${memberId} — rate limited`)
    return new Response(
      JSON.stringify({ skipped: true, reason: 'rate_limited' }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Fetch up to 5 upcoming meetings
  const { data: meetings } = await db
    .from('fellowship_meetings')
    .select('id, title, description, starts_at, ends_at, location, meet_link')
    .eq('fellowship_id', fellowshipId)
    .eq('is_cancelled', false)
    .gte('starts_at', new Date().toISOString())
    .order('starts_at', { ascending: true })
    .limit(5)

  if (!meetings || meetings.length === 0) {
    console.log(`[invite-member] No upcoming meetings for fellowship ${fellowshipId}`)
    return new Response(
      JSON.stringify({ success: true, meetingCount: 0 }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Fetch fellowship name
  const { data: fellowship } = await db
    .from('fellowships')
    .select('name')
    .eq('id', fellowshipId)
    .maybeSingle()
  const fellowshipName = fellowship?.name ?? 'your fellowship'

  // Fetch member email
  const { data: userData } = await db.auth.admin.getUserById(memberId)
  const memberEmail = userData?.user?.email ?? null

  // Fetch member language from user_profiles (canonical source — matches notification-helper-service.ts)
  const { data: profile } = await db
    .from('user_profiles')
    .select('language_preference')
    .eq('id', memberId)
    .maybeSingle()
  const language: string = profile?.language_preference ?? 'en'

  // Fetch timezone offset from user_notification_preferences
  const { data: prefs } = await db
    .from('user_notification_preferences')
    .select('timezone_offset_minutes')
    .eq('user_id', memberId)
    .maybeSingle()
  const tzOffsetMinutes: number = prefs?.timezone_offset_minutes ?? 0

  // Send email if available
  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  if (memberEmail && resendApiKey) {
    const subject = language === 'hi'
      ? `${fellowshipName} में स्वागत है! आगामी मीटिंग्स`
      : language === 'ml'
        ? `${fellowshipName}-ലേക്ക് സ്വാഗതം! ആഗതമായ യോഗങ്ങൾ`
        : `Welcome to ${fellowshipName}! Here are your upcoming meetings`

    const meetingRows = meetings.map((m: {
      title: string; description: string | null; starts_at: string; location: string | null; meet_link: string
    }) => {
      const d = new Date(m.starts_at)
      const local = new Date(d.getTime() + tzOffsetMinutes * 60 * 1000)
      const dateStr = local.toISOString().replace('T', ' ').substring(0, 16) + ' (local)'
      const loc = m.location ?? m.meet_link ?? ''
      return `<tr>
        <td style="padding:10px 14px;border-bottom:1px solid #2a2a40;color:#e0e0f0;font-size:13px;font-weight:600;">${escHtml(m.title)}</td>
        <td style="padding:10px 14px;border-bottom:1px solid #2a2a40;color:#a0a0c0;font-size:12px;">${dateStr}</td>
        <td style="padding:10px 14px;border-bottom:1px solid #2a2a40;color:#6366f1;font-size:12px;">${escHtml(loc)}</td>
      </tr>`
    }).join('')

    const html = `<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#0f0f1a;font-family:'Inter',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#0f0f1a;padding:32px 16px;">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;">
        <tr><td style="padding-bottom:24px;text-align:center;">
          <span style="font-size:22px;font-weight:800;color:#fff;letter-spacing:-0.5px;">Disciplefy</span>
        </td></tr>
        <tr><td style="background:#1a1a2e;border-radius:20px;overflow:hidden;border:1px solid #2a2a40;">
          <div style="height:4px;background:linear-gradient(90deg,#4f46e5,#6366f1);"></div>
          <table width="100%" cellpadding="0" cellspacing="0" style="padding:28px 28px 24px;">
            <tr><td style="padding-bottom:16px;">
              <div style="font-size:18px;font-weight:800;color:#fff;">📅 ${escHtml(subject)}</div>
            </td></tr>
            <tr><td style="padding-bottom:20px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#12122a;border-radius:12px;overflow:hidden;">
                <tr>
                  <th style="padding:10px 14px;text-align:left;font-size:11px;color:#6366f1;text-transform:uppercase;letter-spacing:0.5px;">Meeting</th>
                  <th style="padding:10px 14px;text-align:left;font-size:11px;color:#6366f1;text-transform:uppercase;letter-spacing:0.5px;">Date &amp; Time</th>
                  <th style="padding:10px 14px;text-align:left;font-size:11px;color:#6366f1;text-transform:uppercase;letter-spacing:0.5px;">Location / Link</th>
                </tr>
                ${meetingRows}
              </table>
            </td></tr>
          </table>
        </td></tr>
        <tr><td style="padding-top:20px;text-align:center;"><p style="margin:0;font-size:12px;color:#404060;">You received this because you joined <span style="color:#6366f1;">Disciplefy</span>.</p></td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`

    try {
      await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${resendApiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from: 'Disciplefy <noreply@disciplefy.in>',
          to: [memberEmail],
          subject,
          html,
        }),
      })
    } catch (emailErr) {
      console.error('[invite-member] Email send failed (non-fatal):', emailErr)
    }
  }

  // Send FCM push if member has a token
  try {
    const { data: tokenRow } = await db
      .from('user_notification_tokens')
      .select('fcm_token')
      .eq('user_id', memberId)
      .maybeSingle()

    if (tokenRow?.fcm_token) {
      const fcm = new FCMService()
      await fcm.sendNotification({
        token: tokenRow.fcm_token,
        notification: {
          title: "You've been added to a fellowship",
          body: `There are ${meetings.length} upcoming meeting${meetings.length > 1 ? 's' : ''}. Check your email for details.`,
        },
        data: { type: 'fellowship_meeting_invite', fellowship_id: fellowshipId },
        android: { priority: 'high' },
        apns: { headers: { 'apns-priority': '10' }, payload: { aps: { sound: 'default' } } },
      })
    }
  } catch (fcmErr) {
    console.error('[invite-member] FCM send failed (non-fatal):', fcmErr)
  }

  // Log the invite for rate limiting
  try {
    await db.from('notification_logs').insert({
      user_id: memberId,
      notification_type: 'meeting_invite',
      title: `Upcoming meetings in ${fellowshipName}`,
      body: `${meetings.length} upcoming meeting(s)`,
      delivery_status: 'sent',
      sent_at: new Date().toISOString(),
    })
  } catch (logErr) {
    console.error('[invite-member] Failed to log notification (non-fatal):', logErr)
  }

  console.log(`[invite-member] Notified ${memberId} of ${meetings.length} meetings in ${fellowshipId}`)
  return new Response(
    JSON.stringify({ success: true, meetingCount: meetings.length }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Sync Google Calendar attendees  POST /fellowship-meetings/sync-calendar
// Authenticated mentor — bulk-syncs all upcoming meetings for a fellowship.
// Reads stored google_refresh_token from each meeting row to avoid requiring
// the mentor to re-authenticate.
// ---------------------------------------------------------------------------

interface SyncCalendarRequest {
  fellowshipId: string
}

interface MeetingSyncResult {
  meetingId: string
  status: 'synced' | 'skipped'
  reason?: string
}

async function handleSyncCalendar(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)

  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: SyncCalendarRequest
  try {
    body = await req.json() as SyncCalendarRequest
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.fellowshipId) throw new AppError('VALIDATION_ERROR', 'fellowshipId is required', 400)

  const db = services.supabaseServiceClient

  // Verify caller is the fellowship mentor
  const { data: isMentor, error: mentorError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowshipId,
    p_user_id: user.id,
  })
  if (mentorError) throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Only the fellowship mentor can sync the calendar', 403)

  // Fetch upcoming meetings that have a Google Calendar event (user_primary only)
  const { data: meetings } = await db
    .from('fellowship_meetings')
    .select('id, calendar_event_id, calendar_type, google_refresh_token')
    .eq('fellowship_id', body.fellowshipId)
    .eq('is_cancelled', false)
    .eq('calendar_type', 'user_primary')
    .gte('starts_at', new Date().toISOString())
    .not('calendar_event_id', 'is', null)
    .neq('calendar_event_id', '')

  if (!meetings || meetings.length === 0) {
    return new Response(
      JSON.stringify({ success: true, syncedMeetings: 0, skippedMeetings: 0, syncedMembers: 0, oauthErrors: [] }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Fetch all active fellowship members' emails
  const { data: memberRows } = await db
    .from('fellowship_members')
    .select('user_id')
    .eq('fellowship_id', body.fellowshipId)
    .eq('is_active', true)

  const memberIds = (memberRows ?? []).map((m: { user_id: string }) => m.user_id)
  const memberEmailEntries = await Promise.all(
    memberIds.map(async (uid: string): Promise<string | null> => {
      try {
        const { data } = await db.auth.admin.getUserById(uid)
        return data?.user?.email ?? null
      } catch { return null }
    })
  )
  const memberEmails = memberEmailEntries.filter((e): e is string => !!e)

  if (memberEmails.length === 0) {
    return new Response(
      JSON.stringify({ success: true, syncedMeetings: 0, skippedMeetings: meetings.length, syncedMembers: 0, oauthErrors: [] }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const results: MeetingSyncResult[] = []
  const oauthErrors: string[] = []

  for (const meeting of meetings) {
    const calendarEventId = meeting.calendar_event_id as string
    const storedRefreshToken = meeting.google_refresh_token as string | null

    if (!storedRefreshToken) {
      results.push({ meetingId: meeting.id, status: 'skipped', reason: 'no_refresh_token' })
      oauthErrors.push(meeting.id)
      continue
    }

    let accessToken: string
    try {
      accessToken = await refreshGoogleAccessToken(storedRefreshToken)
    } catch (refreshErr) {
      console.error(`[sync-calendar] Token refresh failed for meeting ${meeting.id}:`, refreshErr)
      results.push({ meetingId: meeting.id, status: 'skipped', reason: 'oauth_expired' })
      oauthErrors.push(meeting.id)
      continue
    }

    try {
      // Fetch current attendees to avoid removing existing ones
      const getRes = await fetch(
        `https://www.googleapis.com/calendar/v3/calendars/primary/events/${calendarEventId}?fields=attendees`,
        { headers: { Authorization: `Bearer ${accessToken}` } }
      )
      const currentEvent = getRes.ok
        ? await getRes.json() as { attendees?: Array<{ email: string }> }
        : { attendees: [] }
      const existingEmails = new Set((currentEvent.attendees ?? []).map((a: { email: string }) => a.email))

      const newAttendees = memberEmails
        .filter(e => !existingEmails.has(e))
        .map(e => ({ email: e }))

      const allAttendees = [...(currentEvent.attendees ?? []), ...newAttendees]

      if (newAttendees.length > 0) {
        const patchRes = await fetch(
          `https://www.googleapis.com/calendar/v3/calendars/primary/events/${calendarEventId}?sendUpdates=added`,
          {
            method: 'PATCH',
            headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ attendees: allAttendees }),
          }
        )
        if (!patchRes.ok) {
          const errText = await patchRes.text()
          console.error(`[sync-calendar] PATCH failed for meeting ${meeting.id}:`, errText)
          results.push({ meetingId: meeting.id, status: 'skipped', reason: 'google_api_error' })
          continue
        }
      }

      await db.from('fellowship_meetings')
        .update({ last_synced_at: new Date().toISOString() })
        .eq('id', meeting.id)

      results.push({ meetingId: meeting.id, status: 'synced' })
    } catch (err) {
      console.error(`[sync-calendar] Error for meeting ${meeting.id}:`, err)
      results.push({ meetingId: meeting.id, status: 'skipped', reason: 'error' })
    }
  }

  const syncedCount = results.filter(r => r.status === 'synced').length
  const skippedCount = results.filter(r => r.status === 'skipped').length

  console.log(`[sync-calendar] Done: ${syncedCount} synced, ${skippedCount} skipped, ${oauthErrors.length} OAuth errors`)

  return new Response(
    JSON.stringify({
      success: true,
      syncedMeetings: syncedCount,
      skippedMeetings: skippedCount,
      syncedMembers: memberEmails.length,
      oauthErrors,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

async function handleMeetings(req: Request, services: ServiceContainer): Promise<Response> {
  const pathname = new URL(req.url).pathname

  // Reminder cron — skip maintenance check (called by GitHub Actions, not user)
  if (req.method === 'POST' && pathname.endsWith('/reminder')) {
    return handleReminder(req, services)
  }

  // Invite member — service-role internal, skip maintenance check
  if (req.method === 'POST' && pathname.endsWith('/invite-member')) {
    return handleInviteMember(req, services)
  }

  await checkMaintenanceMode(req, services)

  if (req.method === 'POST' && pathname.endsWith('/sync-calendar')) {
    return handleSyncCalendar(req, services)
  }

  if (req.method === 'GET') return handleListMeetings(req, services)

  if (req.method === 'POST') {
    if (pathname.endsWith('/cancel')) return handleCancelMeeting(req, services)
    return handleCreateMeeting(req, services)
  }

  throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)
}

createSimpleFunction(handleMeetings, {
  allowedMethods: ['GET', 'POST'],
  enableAnalytics: true,
  timeout: 20000,
})
