/**
 * Guest identity and the full-account requirement.
 *
 * A Supabase anonymous user (JWT claim `is_anonymous: true`, Postgres role
 * `authenticated`, see https://supabase.com/docs/guides/auth/auth-anonymous)
 * is a real auth.users row. It is treated as an authenticated user flagged
 * `isGuest: true`, so RLS and every `userId` check keep working and guest
 * progress lives under the same user id that sign-up later links.
 *
 * The legacy anon-key + `x-session-id` path (and `allowGuestOnJwtFailure`) is
 * unchanged and still yields `type: 'anonymous'`.
 *
 * Contract review of `type === 'anonymous'` / `type !== 'authenticated'` checks
 * (2026-10-07):
 * - Account-only, closed by `requireFullAccount` (or `isAnonymousAuthUser` on
 *   raw `serve`): purchase-tokens, confirm-token-purchase, confirm-apple-purchase,
 *   create-subscription, create-standard-subscription, create-plus-subscription,
 *   cancel-subscription, resume-subscription, start-premium-trial,
 *   upload-profile-image, report-purchase-issue (plus the rest of ACCOUNT_ONLY_FUNCTIONS below, which
 *   authenticate through getUserFromToken / the factory context). Memory verse
 *   functions are account-only too (reason `memory_verses`, 2026-10-07).
 * - Guest-allowed, now pass for guests because guests are `authenticated`:
 *   daily-verse, learning-paths (one guest_accessible path), topic-progress,
 *   continue-learning, study-generate-v2 (verified free lessons of that path
 *   only; study-generate refuses guests, reason `generate`), study-guides,
 *   mark-study-guide-complete, token-status, system-config, user-profile, profile-setup, save-personalization,
 *   personal-notes, study-reflections, topics-for-you, register-fcm-token,
 *   reset-progress, delete-account, use-streak-freeze, get-daily-goal,
 *   get-active-challenges, generate-invoice-pdf (a guest has no invoices), send-streak-notification.
 * - Shared: study-guide-repository (creator_session_id only for legacy sessions),
 *   reflections-service, personal-notes-service, auth-service (guests resolve
 *   to the free plan without a lookup).
 */

import type { UserContext } from '../types/index.ts'
import type { VerifiedIdentity } from './jwt-verifier.ts'
import { ErrorHandler } from '../utils/error-handler.ts'

/** Functions a guest may not use: fellowships, Discipler, payments, purchase issues, profile image, memory verses. */
export const ACCOUNT_ONLY_FUNCTIONS: readonly string[] = [
  'fellowship',
  'fellowship-blocks',
  'fellowship-comments',
  'fellowship-invites',
  'fellowship-meetings',
  'fellowship-members',
  'fellowship-posts',
  'fellowship-study',
  'voice-conversation',
  'conversation-history',
  'study-followup',
  'create-subscription',
  'create-subscription-v2',
  'create-standard-subscription',
  'create-plus-subscription',
  'purchase-tokens',
  'confirm-token-purchase',
  'confirm-apple-purchase',
  'cancel-subscription',
  'resume-subscription',
  'start-premium-trial',
  'validate-promo-code',
  'upload-profile-image',
  'report-purchase-issue',
  // Memory verses (reason `memory_verses`), see MEMORY_VERSE_FUNCTIONS.
  'add-memory-verse-from-daily',
  'add-memory-verse-manual',
  'delete-memory-verse',
  'get-due-memory-verses',
  'get-memory-champions-leaderboard',
  'get-memory-practice-stats',
  'get-memory-statistics',
  'get-memory-streak',
  'submit-memory-practice',
  'submit-memory-verse-review',
]

/** Discipler functions (they spend model tokens): account-only, reason `discipler`. */
export const DISCIPLER_FUNCTIONS: readonly string[] = [
  'study-followup',
  'voice-conversation',
  'conversation-history',
]

/** Memory verse functions a client calls: account-only, reason `memory_verses`. */
export const MEMORY_VERSE_FUNCTIONS: readonly string[] = [
  'add-memory-verse-from-daily',
  'add-memory-verse-manual',
  'delete-memory-verse',
  'get-due-memory-verses',
  'get-memory-champions-leaderboard',
  'get-memory-practice-stats',
  'get-memory-statistics',
  'get-memory-streak',
  'submit-memory-practice',
  'submit-memory-verse-review',
]

/** Memory verse jobs (service role / cron secret), not called by users: left ungated. */
export const MEMORY_VERSE_JOBS: readonly string[] = [
  'refresh-stale-memory-verses',
  'send-memory-verse-notification',
]

export const ACCOUNT_REQUIRED_CODE = 'ACCOUNT_REQUIRED'
export const ACCOUNT_REQUIRED_MESSAGE = 'Create an account to use this.'

/** A Supabase anonymous user is a real auth.users row: treat it as authenticated, flagged as a guest. */
export function toUserContext(identity: Pick<VerifiedIdentity, 'id' | 'email' | 'isAnonymous'>): UserContext {
  return {
    type: 'authenticated',
    userId: identity.id,
    isGuest: identity.isAnonymous,
    email: identity.isAnonymous ? undefined : identity.email,
  }
}

/**
 * Throws ACCOUNT_REQUIRED (403) unless the caller is a signed-in, non-guest user.
 * [reason], when given, is sent as `error.details.reason` for the client's
 * account-needed sheet (e.g. `memory_verses`).
 */
export function assertFullAccount(ctx?: UserContext, reason?: string | null): void {
  if (!ctx || ctx.type !== 'authenticated' || ctx.isGuest) {
    throw ErrorHandler.createAccountRequiredError(
      ACCOUNT_REQUIRED_MESSAGE,
      reason ? { reason } : undefined,
    )
  }
}

/**
 * The factory's post-auth gate. Applies only to callers that presented a user
 * JWT (`type: 'authenticated'`). Tokenless and legacy `x-session-id` callers
 * reach the handler, whose own authentication rejects them as before; this
 * keeps deliberately public routes (e.g. `fellowship-posts/share`) working.
 * A user JWT that fails verification on such a function is rejected by the
 * factory (401) before this runs, so a guest cannot slip through to a handler
 * that re-reads the identity itself.
 */
export function enforceFullAccount(required: boolean, ctx?: UserContext, reason?: string | null): void {
  if (required && ctx?.type === 'authenticated') assertFullAccount(ctx, reason)
}

/** For functions on raw `serve` that call `auth.getUser` themselves. */
export function isAnonymousAuthUser(user: { is_anonymous?: boolean | null }): boolean {
  return user.is_anonymous === true
}
