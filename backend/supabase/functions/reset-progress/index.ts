/**
 * Reset Progress Edge Function
 *
 * Lets an authenticated user irreversibly wipe their own progress for one
 * feature area:
 *
 * - `learning_paths` — enrollments, topic progress, study streak, and
 *   study/streak achievements. Zeroes leaderboard XP as a side effect,
 *   because XP is derived from user_topic_progress.
 * - `memory_verses` — the whole memory verse deck plus collections, daily
 *   goals, unlocked modes, memory challenge progress, memory achievements,
 *   and the memory streak.
 *
 * Security:
 * - Authenticated users only. Guest sessions are rejected.
 * - user_id comes from the validated JWT, never from the request body, so a
 *   user cannot reset someone else's data.
 * - `scope` is checked against a two-value allowlist and mapped to an RPC
 *   name through a literal lookup — never string interpolation.
 * - Rate limited to 5 resets per hour per user, enforced via the DB-backed
 *   `RateLimiter` (not the in-memory one, which resets on every cold start
 *   and never actually engages across concurrent isolates). The identifier
 *   is namespaced (`reset-progress:<userId>`) so this endpoint gets its own
 *   bucket in the shared `rate_limit_usage` table instead of sharing counts
 *   with study generation, subscriptions, and token purchases.
 *
 * Each RPC runs its deletes in a single transaction, so there is no
 * partial-reset state and retrying after a timeout is safe.
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { RateLimiter } from '../_shared/services/rate-limiter.ts'
import { resolveResetRpc } from '../_shared/utils/reset-scope.ts'

/**
 * 5 resets per hour per authenticated user. This endpoint always rejects
 * guests before the rate limiter runs, so the anonymous limit is never
 * exercised; it is left at the class default.
 */
const RESET_RATE_LIMIT_CONFIG = {
  authenticatedLimit: 5,
  authenticatedWindowMinutes: 60,
}

interface ResetProgressData {
  readonly scope: string
  readonly counts: Record<string, unknown>
}

interface ResetProgressResponse extends ApiSuccessResponse<ResetProgressData> {}

async function handleResetProgress(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  // Authenticated users only — a guest has no server-side progress to reset
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError(
      'AUTHENTICATION_ERROR',
      'Authentication required to reset progress',
      401
    )
  }

  const userId = userContext.userId

  // Rate limit per user, not per IP — this is a per-account destructive action.
  // Namespaced identifier isolates this endpoint's bucket in the shared
  // rate_limit_usage table (see module header). Only requests that pass the
  // check record usage, so a rejected request doesn't itself consume quota.
  const resetLimiter = new RateLimiter(services.supabaseServiceClient, RESET_RATE_LIMIT_CONFIG)
  const rateLimitIdentifier = `reset-progress:${userId}`
  const rateLimitResult = await resetLimiter.checkRateLimit(rateLimitIdentifier, 'authenticated')
  if (!rateLimitResult.allowed) {
    throw new AppError(
      'RATE_LIMIT_EXCEEDED',
      'Too many reset attempts. Please try again later.',
      429
    )
  }
  await resetLimiter.recordUsage(rateLimitIdentifier, 'authenticated')

  // Parse body
  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }

  // `null`, arrays, and primitives are all valid JSON but not a usable body —
  // reject them explicitly so we throw a VALIDATION_ERROR (400) instead of
  // letting `body.scope` on a non-object raise an uncaught TypeError that
  // escapes as a 500.
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw new AppError('VALIDATION_ERROR', 'Request body must be a JSON object', 400)
  }

  // Validate scope against the allowlist and resolve the RPC name.
  // Throws VALIDATION_ERROR for anything unexpected.
  const rpcName = resolveResetRpc(body.scope)
  const scope = body.scope as string

  // Call the RPC with the JWT's user id. body.user_id, if present, is ignored.
  const { data, error } = await services.supabaseServiceClient.rpc(rpcName, {
    p_user_id: userId,
  })

  if (error) {
    console.error('[ResetProgress] RPC error:', {
      scope,
      rpc: rpcName,
      message: error.message,
    })
    throw new AppError('DATABASE_ERROR', 'Failed to reset progress', 500)
  }

  const counts = (data ?? {}) as Record<string, unknown>

  // Analytics: scope and counts only, never verse text or references
  try {
    await services.analyticsLogger.logEvent(
      'user_progress_reset',
      {
        user_id: userId,
        scope,
        counts,
      },
      req.headers.get('x-forwarded-for')
    )
  } catch (analyticsError) {
    console.error('[ResetProgress] Analytics logging failed:', {
      error: analyticsError,
      user_id: userId,
      scope,
    })
    // Non-fatal — the reset already succeeded
  }

  const response: ResetProgressResponse = {
    success: true,
    data: { scope, counts },
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}

createAuthenticatedFunction(handleResetProgress, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 30000, // 30s — deleting a large verse deck cascades to several tables
})
