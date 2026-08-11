import { AppError } from './error-handler.ts'

/**
 * The subset of the Supabase client surface this helper needs. Declared
 * structurally so the function can be unit-tested without a live client.
 */
export interface SupabaseLike {
  rpc(fn: string, args: Record<string, unknown>): Promise<{ data: unknown; error: unknown }>
  from(table: string): {
    select(columns: string): {
      eq(column: string, value: string): Promise<{ data: unknown; error: unknown }>
    }
  }
}

/**
 * Author IDs whose content must not be shown to [userId] in [fellowshipId]:
 * everyone in a mutual block relationship with them, plus members muted by a
 * mentor. Returns an empty array when nothing is hidden.
 *
 * Shared by fellowship-posts and fellowship-comments so the two can never
 * disagree about who is hidden.
 */
export async function hiddenAuthorIds(
  db: SupabaseLike,
  userId: string,
  fellowshipId: string
): Promise<string[]> {
  const [blockedResult, mutesResult] = await Promise.all([
    db.rpc('blocked_user_ids', { p_user_id: userId }),
    db.from('fellowship_mutes').select('muted_user_id').eq('fellowship_id', fellowshipId)
  ])

  if (blockedResult.error) {
    console.error('[hidden-authors] blocked_user_ids error:', blockedResult.error)
    throw new AppError('DATABASE_ERROR', 'Failed to resolve blocked users', 500)
  }
  if (mutesResult.error) {
    console.error('[hidden-authors] mutes query error:', mutesResult.error)
    throw new AppError('DATABASE_ERROR', 'Failed to resolve muted members', 500)
  }

  return [...new Set([
    ...((blockedResult.data ?? []) as { user_id: string }[]).map((r) => r.user_id),
    // Mutes are one-directional: a muted member must still see their OWN
    // posts, so exclude userId from the muted set before merging.
    ...((mutesResult.data ?? []) as { muted_user_id: string }[])
      .map((r) => r.muted_user_id)
      .filter((mutedId) => mutedId !== userId)
  ])]
}
