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

  // 1. Null out fellowship_invites.used_by (NO ACTION default would block deletion)
  await db
    .from('fellowship_invites')
    .update({ used_by: null })
    .eq('used_by', userId)

  // 2. Delete fellowships where user is mentor (ON DELETE RESTRICT would block deletion).
  //    fellowship_members, fellowship_posts, fellowship_comments, fellowship_invites
  //    all cascade from fellowships, so this cleans up the whole fellowship.
  await db
    .from('fellowships')
    .delete()
    .eq('mentor_user_id', userId)

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
  allowedMethods: ['DELETE'],
  enableAnalytics: false,
  timeout: 15000,
})
