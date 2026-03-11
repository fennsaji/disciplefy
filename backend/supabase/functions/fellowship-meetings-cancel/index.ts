/**
 * fellowship-meetings-cancel
 * Mentor cancels a meeting — deletes the Google Calendar event and marks DB row cancelled.
 * POST /fellowship-meetings-cancel
 * Auth: Required (mentor only)
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
import { cancelCalendarEvent } from '../_shared/utils/google-calendar.ts'

interface CancelMeetingRequest {
  meeting_id: string
  /** Mentor's Google OAuth access token (calendar.events scope). Required to
   *  delete user_primary events (created via the mentor's own Google account).
   *  The frontend obtains this via a silent GoogleSignIn scope check — the same
   *  flow used when creating the meeting. Not needed for service_account events. */
  google_access_token?: string
}

async function handleCancelMeeting(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)

  let body: CancelMeetingRequest
  try {
    body = await req.json() as CancelMeetingRequest
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }
  if (!body.meeting_id) throw new AppError('VALIDATION_ERROR', 'meeting_id is required', 400)

  const db = services.supabaseServiceClient

  // Fetch the meeting to get fellowship_id, calendar_event_id, and calendar_type
  const { data: meeting, error: fetchError } = await db
    .from('fellowship_meetings')
    .select('id, fellowship_id, calendar_event_id, calendar_type, is_cancelled, created_by')
    .eq('id', body.meeting_id)
    .maybeSingle()

  if (fetchError) throw new AppError('DATABASE_ERROR', 'Failed to fetch meeting', 500)
  if (!meeting) throw new AppError('NOT_FOUND', 'Meeting not found', 404)
  if (meeting.is_cancelled) throw new AppError('CONFLICT', 'Meeting is already cancelled', 409)

  // Mentor check — must be mentor of THIS fellowship
  const { data: isMentor, error: mentorError } = await db.rpc('is_fellowship_mentor', {
    p_fellowship_id: meeting.fellowship_id,
    p_user_id: user.id,
  })
  if (mentorError) throw new AppError('DATABASE_ERROR', 'Failed to verify mentor status', 500)
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Only the fellowship mentor can cancel meetings', 403)

  // Cancel Google Calendar event — log errors but don't block DB update.
  // Passes calendar_type so cancelCalendarEvent targets the correct calendar:
  //   'service_account' → SA calendar (GOOGLE_CALENDAR_ID)
  //   'user_primary'    → skip (SA has no access to user's personal calendar)
  if (meeting.calendar_event_id) {
    try {
      await cancelCalendarEvent(
        meeting.calendar_event_id,
        meeting.calendar_type ?? 'service_account',
        body.google_access_token,
      )
    } catch (err) {
      console.error('[fellowship-meetings-cancel] Google Calendar error (non-blocking):', err)
    }
  } else {
    console.warn('[fellowship-meetings-cancel] No calendar_event_id on meeting:', body.meeting_id)
  }

  // Mark cancelled in DB
  const { error: updateError } = await db
    .from('fellowship_meetings')
    .update({ is_cancelled: true })
    .eq('id', body.meeting_id)

  if (updateError) {
    console.error('[fellowship-meetings-cancel] DB update error:', updateError)
    throw new AppError('DATABASE_ERROR', 'Failed to cancel meeting', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Meeting cancelled' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createSimpleFunction(handleCancelMeeting, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000,
})
