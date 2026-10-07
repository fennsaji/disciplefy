/**
 * Enrolment rules and helpers for the learning-paths function.
 *
 * A guest (Supabase anonymous user) may hold one learning path: they can
 * enrol their first path and re-enrol it, but a second, different path needs
 * an account.
 */

import { AppError, ErrorHandler } from '../_shared/utils/error-handler.ts'

/** True when the path is already enrolled, or when no path is enrolled yet. */
export function canGuestEnroll(enrolledPathIds: string[], pathId: string): boolean {
  return enrolledPathIds.length === 0 || enrolledPathIds.includes(pathId)
}

/** Throws ACCOUNT_REQUIRED (403, reason `second_path`) when a guest may not enrol. */
export function assertGuestMayEnroll(enrolledPathIds: string[], pathId: string): void {
  if (!canGuestEnroll(enrolledPathIds, pathId)) {
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
