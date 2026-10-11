/**
 * Delete Account Edge Function
 *
 * Permanently deletes the authenticated user's account and all associated data.
 * Never deletes a fellowship: each one the user owns is handed to another
 * mentor or member first (hand_over_fellowships), or deactivated when nobody
 * else is in it. Every FK to auth.users either cascades or is SET NULL.
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { cancelCalendarEvent } from '../_shared/utils/google-calendar.ts'

/** Revokes a Google OAuth refresh token at Google's authorization server.
 *  Errors are swallowed — revocation is best-effort so account deletion is
 *  never blocked by a token that may already be expired or revoked. */
async function revokeGoogleToken(token: string): Promise<void> {
  try {
    await fetch(
      `https://oauth2.googleapis.com/revoke?token=${encodeURIComponent(token)}`,
      { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
    )
  } catch (err) {
    console.warn('[DeleteAccount] Google token revocation error (non-fatal):', err)
  }
}

async function handleDeleteAccount(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  }

  const userId = userContext.userId
  const db = services.supabaseServiceClient

  // 1. Revoke Google OAuth tokens and cancel Google Calendar events for all
  //    meetings created by this mentor. Done before deleting rows so we still
  //    have the calendar_event_id and encrypted refresh token to work with.
  try {
    const { data: meetings } = await db
      .from('fellowship_meetings')
      .select('id, calendar_event_id, calendar_type, google_refresh_token')
      .eq('created_by', userId)
      .eq('is_cancelled', false)

    for (const meeting of meetings ?? []) {
      // Cancel the Google Calendar event (non-fatal).
      if (meeting.calendar_event_id) {
        try {
          await cancelCalendarEvent(meeting.calendar_event_id, meeting.calendar_type ?? 'service_account')
        } catch (err) {
          console.warn(`[DeleteAccount] Calendar event cancel failed (non-fatal): ${meeting.calendar_event_id}`, err)
        }
      }

      // Revoke the stored refresh token if present. Decrypt first (tokens are
      // encrypted at rest); fall back to raw value for legacy unencrypted rows.
      if (meeting.google_refresh_token) {
        let tokenToRevoke: string = meeting.google_refresh_token
        try {
          const { data: decrypted } = await db.rpc('decrypt_payment_token', {
            p_encrypted_token: meeting.google_refresh_token,
          })
          if (decrypted) tokenToRevoke = decrypted
        } catch { /* use raw value */ }
        await revokeGoogleToken(tokenToRevoke)
      }
    }
  } catch (err) {
    console.warn('[DeleteAccount] Google cleanup failed (non-fatal):', err)
  }

  // 2. Hand over every fellowship the user owns. Must succeed before the user
  //    is deleted, so a fellowship is never left without an owner by accident.
  const { error: handOverError } = await db.rpc('hand_over_fellowships', { p_user: userId })
  if (handOverError) {
    console.error('[DeleteAccount] Fellowship hand-over failed:', handOverError.code)
    throw new AppError('DATABASE_ERROR', 'Failed to delete account', 500)
  }

  // 3. Delete the auth user — all remaining related data cascades via FK constraints
  const { error } = await db.auth.admin.deleteUser(userId)

  if (error) {
    console.error('[DeleteAccount] Failed to delete user:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to delete account', 500)
  }

  console.log(`[DeleteAccount] Account deleted for user: ${userId}`)

  return new Response(
    JSON.stringify({ success: true }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

createAuthenticatedFunction(handleDeleteAccount, {
  // Payments / subscription / account / admin: session revocation must be honoured.
  verifyWithAuthServer: true,
  allowedMethods: ['DELETE'],
  enableAnalytics: false,
  timeout: 30000,
})
