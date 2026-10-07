/**
 * Pure helpers for `POST /user-profile?action=merge_guest`.
 *
 * A signed-in (non-guest) user sends the access token of the guest session
 * they used on this device in `x-guest-token`. The guest's progress is then
 * merged into their account by `public.merge_guest_progress` (service role).
 */

export const GUEST_TOKEN_HEADER = 'x-guest-token'
export const GUEST_TOKEN_INVALID = 'GUEST_TOKEN_INVALID'

/** Access tokens are a few hundred bytes to ~2 KB; anything larger is not one. */
const MAX_GUEST_TOKEN_LENGTH = 4096
const JWT_SHAPE = /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$/

export interface GuestIdentity {
  readonly id: string
  readonly isAnonymous: boolean
}

export interface MergeCounts {
  readonly topics: number
  readonly paths: number
  readonly guides: number
  readonly verses: number
}

/**
 * Returns an error code, or null when the merge may proceed: the guest token
 * verified, belongs to an anonymous user, and is not the caller's own id.
 */
export function validateMergeRequest(callerId: string, guest: GuestIdentity | null): string | null {
  if (!callerId) return GUEST_TOKEN_INVALID
  if (!guest || !guest.id) return GUEST_TOKEN_INVALID
  if (guest.isAnonymous !== true) return GUEST_TOKEN_INVALID
  if (guest.id === callerId) return GUEST_TOKEN_INVALID
  return null
}

/** Reads the guest JWT from its header (an optional `Bearer ` prefix is accepted). */
export function readGuestToken(req: Request): string | null {
  const raw = req.headers.get(GUEST_TOKEN_HEADER)
  if (!raw) return null
  const token = raw.trim().replace(/^Bearer\s+/i, '')
  if (!token || token.length > MAX_GUEST_TOKEN_LENGTH) return null
  return JWT_SHAPE.test(token) ? token : null
}

function count(value: unknown): number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : 0
}

/** The RPC's jsonb result reduced to the four counts the client reads. */
export function normalizeMergeCounts(result: unknown): MergeCounts {
  const r = (result && typeof result === 'object' ? result : {}) as Record<string, unknown>
  return {
    topics: count(r.topics),
    paths: count(r.paths),
    guides: count(r.guides),
    verses: count(r.verses),
  }
}
