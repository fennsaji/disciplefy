/**
 * Delete Account Edge Function
 *
 * Permanently deletes the authenticated user's account and all associated data.
 * Handles FK constraints that would otherwise block auth.admin.deleteUser:
 *   - fellowships.mentor_user_id  ON DELETE RESTRICT  → delete fellowships the user mentors
 *   - fellowship_invites.used_by  NO ACTION (default) → null out used_by references
 *
 * All other tables cascade automatically from auth.users deletion.
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

  // 2. Null out fellowship_invites.used_by (NO ACTION default would block deletion)
  await db
    .from('fellowship_invites')
    .update({ used_by: null })
    .eq('used_by', userId)

  // 3. Delete fellowships where user is mentor (ON DELETE RESTRICT would block deletion).
  //    fellowship_members, fellowship_posts, fellowship_comments, fellowship_invites
  //    all cascade from fellowships, so this cleans up the whole fellowship.
  await db
    .from('fellowships')
    .delete()
    .eq('mentor_user_id', userId)

  // 4. Delete the auth user — all remaining related data cascades via FK constraints
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
  allowedMethods: ['DELETE'],
  enableAnalytics: false,
  timeout: 30000,
})
