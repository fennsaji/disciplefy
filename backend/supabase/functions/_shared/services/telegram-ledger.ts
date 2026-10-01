/**
 * Claim-then-send ledger for the daily Telegram jobs.
 *
 * A day's slot (post_date, language) is claimed as 'pending' before the
 * message is sent, then marked 'sent' or 'failed'. A retry skips a slot that is
 * 'sent' or freshly 'pending', so a ledger write that fails after a successful
 * send can never cause a repost. 'failed' slots and stale 'pending' slots (a run
 * that died mid-way) can be reclaimed.
 */

// deno-lint-ignore no-explicit-any
type SupabaseLike = any

import { AppError } from '../utils/error-handler.ts'

export type LedgerTable = 'telegram_daily_posts' | 'telegram_daily_verse_posts'

/** A pending claim older than this is treated as abandoned and may be retried. */
export const STALE_CLAIM_MS = 15 * 60 * 1000

export type ClaimResult =
  | { claimed: true }
  | { claimed: false; status: 'sent' | 'pending' | 'unknown'; error?: string }

export async function claimDailySlot(
  supabase: SupabaseLike,
  table: LedgerTable,
  postDate: string,
  language: string,
  fields: Record<string, unknown>,
  now: Date = new Date(),
): Promise<ClaimResult> {
  const claim = { ...fields, status: 'pending', error: null, message_id: null, claimed_at: now.toISOString() }

  const { data: inserted, error: insertError } = await supabase
    .from(table)
    .upsert({ post_date: postDate, language, ...claim }, { onConflict: 'post_date,language', ignoreDuplicates: true })
    .select('id')
  if (insertError) return { claimed: false, status: 'unknown', error: insertError.message }
  if (Array.isArray(inserted) && inserted.length > 0) return { claimed: true }

  // Row exists: take it over only if it failed or its claim went stale.
  const staleBefore = new Date(now.getTime() - STALE_CLAIM_MS).toISOString()
  const { data: reclaimed, error: reclaimError } = await supabase
    .from(table)
    .update(claim)
    .eq('post_date', postDate)
    .eq('language', language)
    .or(`status.eq.failed,and(status.eq.pending,claimed_at.lt.${staleBefore}),and(status.eq.pending,claimed_at.is.null)`)
    .select('id')
  if (reclaimError) return { claimed: false, status: 'unknown', error: reclaimError.message }
  if (Array.isArray(reclaimed) && reclaimed.length > 0) return { claimed: true }

  const { data: row } = await supabase
    .from(table)
    .select('status')
    .eq('post_date', postDate)
    .eq('language', language)
    .maybeSingle()
  return { claimed: false, status: row?.status === 'sent' ? 'sent' : 'pending' }
}

/** Records the outcome of a claimed slot. Retries once; never throws. */
export async function settleDailySlot(
  supabase: SupabaseLike,
  table: LedgerTable,
  postDate: string,
  language: string,
  outcome: { ok: boolean; messageId: number | null; error: string | null },
): Promise<boolean> {
  const update = { status: outcome.ok ? 'sent' : 'failed', message_id: outcome.messageId, error: outcome.error }
  for (let attempt = 0; attempt < 2; attempt++) {
    const { error } = await supabase.from(table).update(update).eq('post_date', postDate).eq('language', language)
    if (!error) return true
    console.error(`[TELEGRAM-LEDGER] ${table} settle failed`, error.message)
  }
  return false
}

export type JobLanguage = 'en' | 'hi' | 'ml'
const JOB_LANGUAGES: readonly string[] = ['en', 'hi', 'ml']

/**
 * Reads { language, dry_run } from a job request. A missing or unsupported
 * language is a caller bug (the scheduler always sends one), so it is rejected
 * with 400 instead of silently posting English.
 */
export async function parseJobRequest(req: Request): Promise<{ language: JobLanguage; dryRun: boolean }> {
  let body: { language?: unknown; dry_run?: unknown } | null = null
  try {
    body = await req.json()
  } catch { /* handled below */ }
  const language = body?.language
  if (typeof language !== 'string' || !JOB_LANGUAGES.includes(language)) {
    throw new AppError('VALIDATION_ERROR', "language is required and must be one of 'en', 'hi', 'ml'", 400)
  }
  return { language: language as JobLanguage, dryRun: body?.dry_run === true }
}
