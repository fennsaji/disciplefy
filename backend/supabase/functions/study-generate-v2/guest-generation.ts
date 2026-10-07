/**
 * What a guest (Supabase anonymous user) may generate.
 *
 * A guest never types a study of their own: they may only open a verified
 * catalogue lesson (the request's title matches the catalogue topic) in a free
 * mode, and only when the topic sits in a path they are enrolled in that is
 * also `guest_accessible`. A topic held by several paths is allowed when ANY
 * one of them is both. Everything else is 403 ACCOUNT_REQUIRED, reason
 * `generate`. Checked before any token or model work.
 */

import { AppError, ErrorHandler } from '../_shared/utils/error-handler.ts'

/**
 * @param isGuest whether the caller is a guest; full accounts are not limited here
 * @param verifiedCatalogue the request is a verified catalogue lesson in a free mode
 * @param enrolledPathIds paths the guest is enrolled in
 * @param topicPathIds paths holding the requested topic
 * @param guestAccessiblePathIds paths flagged guest_accessible
 */
export function guestMayGenerate(
  isGuest: boolean,
  verifiedCatalogue: boolean,
  enrolledPathIds: readonly string[],
  topicPathIds: readonly string[],
  guestAccessiblePathIds: readonly string[],
): boolean {
  if (!isGuest) return true
  if (!verifiedCatalogue) return false
  return topicPathIds.some((id) => enrolledPathIds.includes(id) && guestAccessiblePathIds.includes(id))
}

/** The minimum of a Supabase client this module needs. */
// deno-lint-ignore no-explicit-any -- the query builder is untyped across this codebase
export type QueryClient = { from(table: string): any }

export interface GuestGenerationScope {
  readonly enrolledPathIds: string[]
  readonly guestAccessiblePathIds: string[]
}

/**
 * Among [topicPathIds], the ones [userId] is enrolled in and the ones open to
 * guests. A failed read is a retryable 503: the gate fails closed.
 */
export async function loadGuestGenerationScope(
  db: QueryClient,
  userId: string,
  topicPathIds: readonly string[],
): Promise<GuestGenerationScope> {
  if (topicPathIds.length === 0) return { enrolledPathIds: [], guestAccessiblePathIds: [] }
  const ids = [...topicPathIds]
  const [enrolledRes, accessibleRes] = await Promise.all([
    db.from('user_learning_path_progress').select('learning_path_id').eq('user_id', userId).in('learning_path_id', ids),
    db.from('learning_paths').select('id').in('id', ids).eq('guest_accessible', true),
  ])
  if (enrolledRes.error || accessibleRes.error) {
    throw new AppError('SERVICE_UNAVAILABLE', 'The lesson could not be loaded. Please try again.', 503)
  }
  return {
    enrolledPathIds: ((enrolledRes.data ?? []) as Array<{ learning_path_id: string }>).map((r) => r.learning_path_id),
    guestAccessiblePathIds: ((accessibleRes.data ?? []) as Array<{ id: string }>).map((r) => r.id),
  }
}

export interface GuestGenerationRequest {
  readonly isGuest: boolean
  readonly userId: string | undefined
  /** A verified catalogue lesson in a free mode. */
  readonly verifiedCatalogue: boolean
  /** Paths holding the requested topic; empty when it is not a lesson. */
  readonly topicPathIds: readonly string[]
}

/** Throws ACCOUNT_REQUIRED (403, reason `generate`) unless the request may proceed. */
export async function assertGuestMayGenerate(db: QueryClient, req: GuestGenerationRequest): Promise<void> {
  if (!req.isGuest) return
  const refuse = () =>
    ErrorHandler.createAccountRequiredError('Create an account to generate your own studies.', { reason: 'generate' })
  if (!req.verifiedCatalogue || !req.userId) throw refuse()
  const scope = await loadGuestGenerationScope(db, req.userId, req.topicPathIds)
  if (!guestMayGenerate(true, true, scope.enrolledPathIds, req.topicPathIds, scope.guestAccessiblePathIds)) {
    throw refuse()
  }
}
