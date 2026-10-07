/**
 * Enrolment rules and helpers for the learning-paths function.
 *
 * A guest (Supabase anonymous user) may hold one learning path, and only one
 * flagged `learning_paths.guest_accessible`: they can enrol their first such
 * path and re-enrol it. Any other path, or a second one, needs an account.
 */

import { AppError, ErrorHandler } from '../_shared/utils/error-handler.ts'

export type GuestEnrollDenial = 'other_path' | 'second_path'

/**
 * Why a guest may not enrol in [pathId], or null when they may.
 *
 * A path that is not guest-accessible is refused first (`other_path`), even
 * when already enrolled. Otherwise the path must be the one already enrolled,
 * or the first (`second_path`).
 */
export function guestEnrollDenial(
  enrolledPathIds: readonly string[],
  pathId: string,
  guestAccessible: boolean,
): GuestEnrollDenial | null {
  if (!guestAccessible) return 'other_path'
  if (enrolledPathIds.length === 0 || enrolledPathIds.includes(pathId)) return null
  return 'second_path'
}

/** True when a guest may enrol in [pathId]. */
export function canGuestEnroll(
  enrolledPathIds: readonly string[],
  pathId: string,
  guestAccessible: boolean,
): boolean {
  return guestEnrollDenial(enrolledPathIds, pathId, guestAccessible) === null
}

/** Throws ACCOUNT_REQUIRED (403, reason `other_path` or `second_path`) when a guest may not enrol. */
export function assertGuestMayEnroll(
  enrolledPathIds: readonly string[],
  pathId: string,
  guestAccessible: boolean,
): void {
  const denial = guestEnrollDenial(enrolledPathIds, pathId, guestAccessible)
  if (denial === 'other_path') {
    throw ErrorHandler.createAccountRequiredError(
      'Create an account to start this path.',
      { reason: 'other_path' },
    )
  }
  if (denial === 'second_path') {
    throw ErrorHandler.createAccountRequiredError(
      'Create an account to start another path.',
      { reason: 'second_path' },
    )
  }
}

export type EnrollTarget = { pathId: string } | { slug: string }

const SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/
const MAX_SLUG_LENGTH = 100

/**
 * Reads the enrol target from the request body (`pathId` wins over `slug`),
 * falling back to a `pathId` query parameter. Slugs are trimmed, lower-cased
 * and checked against the kebab-case format learning_paths.slug uses.
 */
export function parseEnrollTarget(body: unknown, queryPathId?: string | null): EnrollTarget {
  const b = (body && typeof body === 'object' ? body : {}) as Record<string, unknown>

  if (typeof b.pathId === 'string' && b.pathId.trim()) {
    return { pathId: b.pathId.trim() }
  }
  if (b.slug !== undefined && b.slug !== null) {
    if (typeof b.slug !== 'string') {
      throw new AppError('VALIDATION_ERROR', 'slug must be a string', 400)
    }
    const slug = b.slug.trim().toLowerCase()
    if (!slug || slug.length > MAX_SLUG_LENGTH || !SLUG_PATTERN.test(slug)) {
      throw new AppError('VALIDATION_ERROR', 'slug is invalid', 400)
    }
    return { slug }
  }
  if (queryPathId && queryPathId.trim()) {
    return { pathId: queryPathId.trim() }
  }
  throw new AppError('VALIDATION_ERROR', 'pathId or slug is required', 400)
}

// deno-lint-ignore no-explicit-any -- supabase-js client, not narrowed here
type Client = any

/** The id of the active learning path with this slug; NOT_FOUND otherwise. */
export async function resolvePathIdBySlug(client: Client, slug: string): Promise<string> {
  const { data, error } = await client
    .from('learning_paths')
    .select('id')
    .eq('slug', slug)
    .eq('is_active', true)
    .maybeSingle()

  if (error) {
    throw new AppError('DATABASE_ERROR', 'Failed to resolve learning path', 500)
  }
  if (!data?.id) {
    throw new AppError('NOT_FOUND', 'Learning path not found or inactive', 404)
  }
  return data.id as string
}

/** Learning path ids the user is enrolled in. */
export async function loadUserEnrolledPathIds(client: Client, userId: string): Promise<string[]> {
  const { data, error } = await client
    .from('user_learning_path_progress')
    .select('learning_path_id')
    .eq('user_id', userId)

  if (error) {
    throw new AppError('DATABASE_ERROR', 'Failed to check enrolments', 500)
  }
  return ((data ?? []) as Array<{ learning_path_id: string }>).map((r) => r.learning_path_id)
}

/**
 * Whether the active path [pathId] is open to guests, read fresh (enrolment is
 * a security decision, so no cache). NOT_FOUND when there is no such active path.
 */
export async function loadPathGuestAccessible(client: Client, pathId: string): Promise<boolean> {
  const { data, error } = await client
    .from('learning_paths')
    .select('guest_accessible')
    .eq('id', pathId)
    .eq('is_active', true)
    .maybeSingle()

  if (error) {
    throw new AppError('DATABASE_ERROR', 'Failed to check learning path', 500)
  }
  if (!data) {
    throw new AppError('NOT_FOUND', 'Learning path not found or inactive', 404)
  }
  return data.guest_accessible === true
}

/**
 * Ids of every guest-accessible path, for labelling list responses. Null when
 * the query fails, so the caller can report no path as guest-accessible (the
 * enrol check reads the flag fresh either way).
 */
export async function loadGuestAccessiblePathIds(client: Client): Promise<Set<string> | null> {
  const { data, error } = await client
    .from('learning_paths')
    .select('id')
    .eq('guest_accessible', true)

  if (error) return null
  return new Set(((data ?? []) as Array<{ id: string }>).map((r) => r.id))
}
