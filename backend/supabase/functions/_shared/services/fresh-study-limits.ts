/**
 * Ceilings on studies that actually call the model.
 *
 * Daily tokens pace a user; they say nothing about the month's bill. A standard
 * guide costs $0.052 in English and $0.150 in Malayalam (measured 9 September
 * 2026), and Standard is free for its first year, so without a monthly ceiling
 * a few enthusiastic users can outspend everyone who pays.
 *
 * Three rules, all counted from usage_logs, which records a generation as
 * `create` and a cache hit as `read`:
 *
 *   - a monthly cap on fresh studies, per plan
 *   - a daily fair-use ceiling for Premium, whose tokens are unlimited and
 *     which therefore has nothing else bounding a single day
 *   - two sermons a day, because sermon is four Sonnet passes and lives on that
 *     same plan
 *
 * Learning-path studies never count. They are served from the catalogue cache,
 * cost nothing to repeat, and are the part of the product that should stay open
 * to everyone.
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getPlanConfigFromDB } from './plan-config-db-service.ts'
import type { UserPlan } from '../types/token-types.ts'

/** A limit of -1 means the plan has none. */
const UNLIMITED = -1

export interface FreshStudyLimitResult {
  readonly allowed: boolean
  /** Which ceiling was reached, when one was. */
  readonly limit?: 'monthly_fresh_studies' | 'daily_fresh_studies' | 'daily_sermons'
  readonly used?: number
  readonly cap?: number
}

/** Midnight UTC on the first of the current month. */
export function startOfMonth(now: Date = new Date()): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
}

/** Midnight UTC today. */
export function startOfDay(now: Date = new Date()): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()))
}

/**
 * Whether [userId] may generate another fresh study.
 *
 * Callers skip this for a learning-path study in its recommended mode and for
 * anything answered from cache: neither costs a model call.
 */
export async function checkFreshStudyLimits(
  db: SupabaseClient,
  userId: string,
  userPlan: UserPlan,
  studyMode: string,
): Promise<FreshStudyLimitResult> {
  const config = await getPlanConfigFromDB(userPlan)
  const features = config.features as Record<string, unknown>

  const monthlyCap = asLimit(features.monthly_fresh_studies)
  const dailyCap = asLimit(features.daily_fresh_studies)
  const sermonCap = asLimit(features.daily_sermons)

  if (studyMode === 'sermon' && sermonCap !== UNLIMITED) {
    const used = await countFresh(db, userId, startOfDay(), 'sermon')
    if (used >= sermonCap) {
      return { allowed: false, limit: 'daily_sermons', used, cap: sermonCap }
    }
  }

  // Premium's fair-use ceiling. The other plans are bounded by daily tokens,
  // so this is unlimited for them and the check costs nothing.
  if (dailyCap !== UNLIMITED) {
    const used = await countFresh(db, userId, startOfDay())
    if (used >= dailyCap) {
      return { allowed: false, limit: 'daily_fresh_studies', used, cap: dailyCap }
    }
  }

  if (monthlyCap !== UNLIMITED) {
    const used = await countFresh(db, userId, startOfMonth())
    if (used >= monthlyCap) {
      return { allowed: false, limit: 'monthly_fresh_studies', used, cap: monthlyCap }
    }
  }

  return { allowed: true }
}

/**
 * The message a user sees when a ceiling is reached.
 *
 * It says what is still open, because the catalogue is: the limit is about what
 * costs us money, not about locking someone out of their reading.
 */
export function limitMessage(result: FreshStudyLimitResult): string {
  if (result.limit === 'daily_sermons') {
    return "You have made today's sermon outlines. Please try again tomorrow."
  }
  if (result.limit === 'daily_fresh_studies') {
    return "You have made today's new studies. All learning-path studies are still open, and your limit resets tomorrow."
  }
  return "You have used this month's new studies. All learning-path studies are still open. Upgrade for more."
}

/** Reads a plan feature as a limit, treating anything missing as unlimited. */
function asLimit(value: unknown): number {
  if (typeof value !== 'number' || Number.isNaN(value)) return UNLIMITED
  return value < 0 ? UNLIMITED : value
}

async function countFresh(
  db: SupabaseClient,
  userId: string,
  since: Date,
  studyMode?: string,
): Promise<number> {
  const { data, error } = await db.rpc('count_fresh_studies', {
    p_user_id: userId,
    p_since: since.toISOString(),
    p_study_mode: studyMode ?? null,
  })

  if (error) {
    // A counting failure must not block a legitimate study. Log it and allow;
    // the daily token limit is still in force underneath.
    console.error('[FreshStudyLimits] count failed, allowing:', error.message)
    return 0
  }
  return typeof data === 'number' ? data : 0
}
