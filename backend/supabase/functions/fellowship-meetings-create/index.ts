/**
 * fellowship-meetings-create
 * Mentor creates a one-time or recurring fellowship meeting.
 * Google Calendar event is created, Meet link generated, all members invited.
 * POST /fellowship-meetings-create
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import { createCalendarEvent, cancelCalendarEvent } from '../_shared/utils/google-calendar.ts'
import { FCMService } from '../_shared/fcm-service.ts'

interface CreateMeetingRequest {
  fellowship_id: string
  title: string
  description?: string
  starts_at: string        // ISO-8601 with timezone
  duration_minutes: number // 30, 60, 90, or 120
  time_zone: string        // IANA timezone e.g. "Asia/Kolkata"
  recurrence?: 'daily' | 'weekly' | 'monthly' | null
  /** Physical gathering location. When provided the meeting is in-person:
   *  no Google Calendar event is created and meet_link is left empty. */
  location?: string
  /** Mentor's Google OAuth access token (calendar.events scope).
   *  When present, used to create a real hangoutsMeet link via Calendar API.
   *  Ignored when [location] is set (in-person meetings don't need Meet links). */
  google_access_token?: string
  /** Google OAuth refresh token (offline access). */
  google_refresh_token?: string
}

/** Escapes characters that have special meaning in HTML to prevent injection. */
function escHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function buildMeetingInviteEmail(opts: {
  title: string
  description?: string | null
  dateStr: string
  timeStr: string
  durationLabel: string
  meetLink: string
  addToCalendarUrl: string
  recurrence?: string | null
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

        <!-- Logo / brand -->
        <tr><td style="padding-bottom:24px;text-align:center;">
          <span style="font-size:22px;font-weight:800;color:#fff;letter-spacing:-0.5px;">Disciplefy</span>
        </td></tr>

        <!-- Card -->
        <tr><td style="background:#1a1a2e;border-radius:20px;overflow:hidden;border:1px solid #2a2a40;">

          <!-- Gradient accent bar -->
          <div style="height:4px;background:linear-gradient(90deg,#4f46e5,#6366f1);"></div>

          <table width="100%" cellpadding="0" cellspacing="0" style="padding:28px 28px 24px;">

            <!-- Header -->
            <tr><td style="padding-bottom:20px;">
              <table cellpadding="0" cellspacing="0">
                <tr>
                  <td style="background:linear-gradient(135deg,#4f46e5,#6366f1);width:48px;height:48px;border-radius:14px;text-align:center;vertical-align:middle;">
                    <span style="font-size:22px;line-height:48px;">📹</span>
                  </td>
                  <td style="padding-left:14px;vertical-align:middle;">
                    <div style="font-size:11px;font-weight:600;color:#6366f1;letter-spacing:1px;text-transform:uppercase;margin-bottom:4px;">Fellowship Meeting</div>
                    <div style="font-size:20px;font-weight:800;color:#fff;line-height:1.2;">${escHtml(opts.title)}${recurrenceBadge}</div>
                  </td>
                </tr>
              </table>
            </td></tr>

            ${opts.description ? `
            <!-- Description -->
            <tr><td style="padding-bottom:20px;">
              <p style="margin:0;font-size:14px;color:#a0a0c0;line-height:1.6;">${escHtml(opts.description)}</p>
            </td></tr>
            ` : ''}

            <!-- Date/time info -->
            <tr><td style="padding-bottom:24px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#12122a;border-radius:12px;padding:0;overflow:hidden;">
                <tr>
                  <td style="padding:14px 18px;border-bottom:1px solid #2a2a40;">
                    <span style="font-size:12px;color:#6366f1;margin-right:8px;">📅</span>
                    <span style="font-size:13px;font-weight:600;color:#e0e0f0;">${opts.dateStr}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:14px 18px;border-bottom:1px solid #2a2a40;">
                    <span style="font-size:12px;color:#6366f1;margin-right:8px;">🕐</span>
                    <span style="font-size:13px;font-weight:600;color:#e0e0f0;">${opts.timeStr}</span>
                    <span style="font-size:12px;color:#6060a0;margin-left:10px;">· ${opts.durationLabel}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:14px 18px;">
                    <span style="font-size:12px;color:#6366f1;margin-right:8px;">🔗</span>
                    <a href="${opts.meetLink}" style="font-size:13px;font-weight:600;color:#6366f1;text-decoration:none;">${opts.meetLink}</a>
                  </td>
                </tr>
              </table>
            </td></tr>

            <!-- Join button -->
            <tr><td style="padding-bottom:14px;">
              <a href="${opts.meetLink}" style="display:block;background:#ffeec0;color:#1a1a2e;text-align:center;padding:14px 24px;border-radius:12px;font-size:15px;font-weight:800;text-decoration:none;letter-spacing:0.2px;">
                ▶ Join Meeting
              </a>
            </td></tr>

            <!-- Add to calendar button -->
            <tr><td>
              <a href="${opts.addToCalendarUrl}" style="display:block;background:transparent;color:#6366f1;text-align:center;padding:12px 24px;border-radius:12px;font-size:14px;font-weight:700;text-decoration:none;border:1.5px solid #6366f1;">
                📆 Add to Google Calendar
              </a>
            </td></tr>

          </table>
        </td></tr>

        <!-- Footer -->
        <tr><td style="padding-top:20px;text-align:center;">
          <p style="margin:0;font-size:12px;color:#404060;">
            You received this because you're a member of this fellowship on <span style="color:#6366f1;">Disciplefy</span>.
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`
}

async function handleCreateMeeting(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  // Auth
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: CreateMeetingRequest
  try {
    body = await req.json() as CreateMeetingRequest
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }

  // Validate required fields
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.title?.trim()) throw new AppError('VALIDATION_ERROR', 'title is required', 400)
  if (body.title.trim().length > 100) throw new AppError('VALIDATION_ERROR', 'title must be 100 characters or fewer', 400)
  if (!body.starts_at) throw new AppError('VALIDATION_ERROR', 'starts_at is required', 400)
  if (!body.time_zone) throw new AppError('VALIDATION_ERROR', 'time_zone is required', 400)

  const startsAt = new Date(body.starts_at)
  if (isNaN(startsAt.getTime())) throw new AppError('VALIDATION_ERROR', 'starts_at must be a valid ISO-8601 date', 400)
  if (startsAt <= new Date()) throw new AppError('VALIDATION_ERROR', 'starts_at must be in the future', 400)

  if (body.duration_minutes === undefined || body.duration_minutes === null) {
    throw new AppError('VALIDATION_ERROR', 'duration_minutes is required', 400)
  }
  const durationMinutes = body.duration_minutes
  if (![30, 60, 90, 120].includes(durationMinutes)) {
    throw new AppError('VALIDATION_ERROR', 'duration_minutes must be 30, 60, 90, or 120', 400)
  }

  if (body.recurrence !== undefined && body.recurrence !== null &&
      !['daily', 'weekly', 'monthly'].includes(body.recurrence)) {
    throw new AppError('VALIDATION_ERROR', 'recurrence must be daily, weekly, monthly, or null', 400)
  }

  const db = services.supabaseServiceClient

  // Mentor check
  const { data: isMentor, error: mentorError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: body.fellowship_id,
    p_user_id: user.id,
  })
  if (mentorError) throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Only the fellowship mentor can schedule meetings', 403)

  // Compute end time
  const endsAt = new Date(startsAt.getTime() + durationMinutes * 60 * 1000)

  // Fetch all active member emails upfront — needed for Calendar attendees
  // when the mentor's Google token is available.
  const { data: memberRows } = await db
    .from('fellowship_members')
    .select('user_id')
    .eq('fellowship_id', body.fellowship_id)
    .eq('is_active', true)

  const memberIds = (memberRows ?? []).map((m: { user_id: string }) => m.user_id)

  let attendeeEmails: string[] = []
  if (body.google_access_token && memberIds.length > 0) {
    const emailEntries = await Promise.all(
      memberIds.map(async (uid: string): Promise<string | null> => {
        try {
          const { data } = await services.supabaseServiceClient.auth.admin.getUserById(uid)
          return data?.user?.email ?? null
        } catch { return null }
      })
    )
    attendeeEmails = emailEntries.filter((e): e is string => e !== null)
  }

  // In-person meetings skip Google Calendar entirely — no Meet link needed.
  const isInPerson = !!body.location?.trim()

  let calendarResult: { eventId: string; meetLink: string; calendarType: 'service_account' | 'user_primary' } =
    { eventId: '', meetLink: '', calendarType: 'service_account' }

  if (!isInPerson) {
    try {
      calendarResult = await createCalendarEvent({
        title: body.title.trim(),
        description: body.description?.trim() ?? null,
        startsAt: startsAt.toISOString(),
        endsAt: endsAt.toISOString(),
        timeZone: body.time_zone,
        recurrence: body.recurrence ?? null,
        attendeeEmails,
        userAccessToken: body.google_access_token,
        userRefreshToken: body.google_refresh_token,
      })
    } catch (err) {
      console.error('[fellowship-meetings-create] Google Calendar error (non-fatal, saving meeting anyway):', err)
    }
  }

  // Store meeting in DB (atomic with calendar creation — if this fails, log orphaned event ID)
  const { data: meeting, error: insertError } = await db
    .from('fellowship_meetings')
    .insert({
      fellowship_id: body.fellowship_id,
      created_by: user.id,
      title: body.title.trim(),
      description: body.description?.trim() ?? null,
      starts_at: startsAt.toISOString(),
      ends_at: endsAt.toISOString(),
      recurrence: body.recurrence ?? null,
      location: body.location?.trim() ?? null,
      meet_link: calendarResult.meetLink,
      calendar_event_id: calendarResult.eventId,
      calendar_type: calendarResult.calendarType,
    })
    .select()
    .single()

  if (insertError) {
    console.error('[fellowship-meetings-create] DB insert error:', insertError)
    // Clean up the orphaned Google Calendar event so attendees don't receive
    // an invite for a meeting that was never saved. Fire-and-forget — we've
    // already decided to throw, so we don't wait for the cleanup to succeed.
    if (calendarResult.eventId) {
      cancelCalendarEvent(calendarResult.eventId, calendarResult.calendarType).catch(err =>
        console.error('[fellowship-meetings-create] Orphan cleanup failed for event', calendarResult.eventId, err)
      )
    }
    throw new AppError('DATABASE_ERROR', 'Failed to save meeting', 500)
  }

  // Schedule FCM reminders — 1 hour and 1 minute before the meeting.
  // Non-fatal: if insert fails the meeting is still created.
  ;(async () => {
    try {
      await db.from('meeting_reminders').insert([
        {
          meeting_id: meeting.id,
          remind_at: new Date(startsAt.getTime() - 60 * 60 * 1000).toISOString(),
          offset_label: '1 hour',
        },
        {
          meeting_id: meeting.id,
          remind_at: new Date(startsAt.getTime() - 10 * 60 * 1000).toISOString(),
          offset_label: '10 minutes',
        },
      ])
    } catch (err) {
      console.error('[fellowship-meetings-create] Failed to schedule reminders (non-fatal):', err)
    }
  })()

  // Notify all active fellowship members — fire-and-forget (non-fatal).
  // Sends both FCM push notifications and Resend email invites.
  ;(async () => {
    try {
      // Fetch all active member user IDs
      const { data: members } = await db
        .from('fellowship_members')
        .select('user_id')
        .eq('fellowship_id', body.fellowship_id)
        .eq('is_active', true)

      const memberIds = (members ?? []).map((m: { user_id: string }) => m.user_id)
      if (memberIds.length === 0) return

      // Format date/time strings for display
      const startsAtDate = new Date(meeting.starts_at)
      const endsAtDate = new Date(meeting.ends_at)
      const dateStr = startsAtDate.toLocaleDateString('en-US', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
      })
      const timeStr = startsAtDate.toLocaleTimeString('en-US', {
        hour: 'numeric', minute: '2-digit', hour12: true,
      })
      const durationMinutes = Math.round(
        (endsAtDate.getTime() - startsAtDate.getTime()) / 60000
      )
      const durationLabel = durationMinutes < 60
        ? `${durationMinutes} min`
        : durationMinutes % 60 === 0
          ? `${durationMinutes / 60} hr`
          : `${Math.floor(durationMinutes / 60)} hr ${durationMinutes % 60} min`

      // Build "Add to Google Calendar" URL (no API needed — standard GCal deeplink)
      const gcalDateFmt = (d: Date) =>
        d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')
      const gcalDetails = encodeURIComponent(
        [meeting.description, `Join meeting: ${meeting.meet_link}`].filter(Boolean).join('\n\n')
      )
      const addToCalendarUrl =
        `https://calendar.google.com/calendar/render?action=TEMPLATE` +
        `&text=${encodeURIComponent(meeting.title)}` +
        `&dates=${gcalDateFmt(startsAtDate)}/${gcalDateFmt(endsAtDate)}` +
        `&details=${gcalDetails}` +
        `&location=${encodeURIComponent(meeting.meet_link)}`

      // ── FCM push notifications ──────────────────────────────────────────
      try {
        const { data: tokenRows } = await db
          .from('user_notification_tokens')
          .select('fcm_token')
          .in('user_id', memberIds)

        const tokens = (tokenRows ?? [])
          .map((r: { fcm_token: string }) => r.fcm_token)
          .filter(Boolean)

        if (tokens.length > 0) {
          const fcm = new FCMService()
          await fcm.sendBatchNotifications(
            tokens,
            {
              title: `📅 New Meeting: ${meeting.title}`,
              body: `${dateStr} at ${timeStr} · ${durationLabel}`,
            },
            {
              type: 'fellowship_meeting',
              fellowship_id: body.fellowship_id,
              meeting_id: meeting.id,
              meet_link: meeting.meet_link,
            },
          )
        }
      } catch (fcmErr) {
        console.error('[fellowship-meetings-create] FCM error (non-fatal):', fcmErr)
      }

      // ── Resend email invites ────────────────────────────────────────────
      const resendApiKey = Deno.env.get('RESEND_API_KEY')
      if (!resendApiKey) {
        console.warn('[fellowship-meetings-create] RESEND_API_KEY not set — skipping email invites')
        return
      }

      // Fetch emails for all members via auth.admin
      const emailEntries = await Promise.all(
        memberIds.map(async (userId: string): Promise<string | null> => {
          try {
            const { data } = await services.supabaseServiceClient.auth.admin.getUserById(userId)
            return data?.user?.email ?? null
          } catch {
            return null
          }
        })
      )
      const emails = emailEntries.filter((e): e is string => e !== null)
      if (emails.length === 0) return

      const html = buildMeetingInviteEmail({
        title: meeting.title,
        description: meeting.description,
        dateStr,
        timeStr,
        durationLabel,
        meetLink: meeting.meet_link,
        addToCalendarUrl,
        recurrence: meeting.recurrence,
      })

      // Send to each member individually (Resend free tier: 1 recipient per call)
      await Promise.allSettled(
        emails.map(email =>
          fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${resendApiKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              from: 'Disciplefy <noreply@disciplefy.in>',
              to: [email],
              subject: `📅 New Fellowship Meeting: ${meeting.title}`,
              html,
            }),
          }).then(r => {
            if (!r.ok) r.text().then(t =>
              console.error(`[fellowship-meetings-create] Resend error for ${email}:`, t)
            )
          })
        )
      )
    } catch (err) {
      console.error('[fellowship-meetings-create] Notification error (non-fatal):', err)
    }
  })()

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        id: meeting.id,
        fellowship_id: meeting.fellowship_id,
        title: meeting.title,
        description: meeting.description,
        starts_at: meeting.starts_at,
        ends_at: meeting.ends_at,
        recurrence: meeting.recurrence,
        location: meeting.location ?? null,
        meet_link: meeting.meet_link,
        created_by: meeting.created_by,
        created_at: meeting.created_at,
      },
    }),
    { status: 201, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleCreateMeeting, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 20000,
})
