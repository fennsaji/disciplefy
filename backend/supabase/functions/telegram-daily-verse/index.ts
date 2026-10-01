/**
 * Telegram Daily Verse — Scheduled Background Job
 *
 * Posts today's daily verse (the same `daily_verses_cache` row the app shows)
 * to the Telegram group's daily-verse topic for one language.
 *
 * The verse is posted with its translation cited and, for the CC BY-SA IRV
 * texts, the licence line. The `bible_content_enabled` kill-switch stops the
 * post entirely.
 *
 * Schedule: cron_config `telegram_daily_verse` (rs-backend), 06:00 IST.
 * Topic: telegram_topics kind 'daily_verse' per language (none = no topic).
 * Idempotent per date + language via telegram_daily_verse_posts.
 * Env: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID.
 */

import { createServiceRoleFunction } from '../_shared/core/function-factory.ts'
import { getServiceContainer } from '../_shared/core/services.ts'
import { isBibleContentEnabled } from '../_shared/services/bible-availability.ts'
import { resolveTelegramThreadId, sendTelegramMessage } from '../_shared/services/telegram-service.ts'
import { DailyVerseService } from '../daily-verse/daily-verse-service.ts'
import { claimDailySlot, parseJobRequest, settleDailySlot } from '../_shared/services/telegram-ledger.ts'
import { buildDailyVerseMessage, verseFor, type VerseLanguage } from './message.ts'

const LEDGER = 'telegram_daily_verse_posts'

createServiceRoleFunction(async (req, supabase) => {
  const { language, dryRun } = await parseJobRequest(req)

  if (!(await isBibleContentEnabled())) {
    console.log('[TELEGRAM-VERSE] bible content disabled, skipping', { language })
    return { success: true, skipped: true, reason: 'bible_content_disabled' }
  }

  // UTC date, the same key daily_verses_cache uses.
  const today = new Date().toISOString().slice(0, 10)

  const { data: existing } = await supabase
    .from('telegram_daily_verse_posts')
    .select('id, reference')
    .eq('post_date', today)
    .eq('language', language)
    .eq('status', 'sent')
    .maybeSingle()

  if (existing && !dryRun) {
    return { success: true, skipped: true, reason: 'already_posted_today', reference: existing.reference }
  }

  const services = await getServiceContainer()
  const verse = await new DailyVerseService(services.supabaseServiceClient, services.getLlmService)
    .getDailyVerse(today, language)

  const picked = verseFor(verse, language)
  if (!picked) {
    console.warn('[TELEGRAM-VERSE] no verse text for language', { language, date: today })
    return { success: true, skipped: true, reason: 'no_verse_text' }
  }

  const message = buildDailyVerseMessage(language, picked.reference, picked.text)
  const threadId = await resolveTelegramThreadId(supabase, 'daily_verse', language)

  if (dryRun) {
    return { success: true, dry_run: true, language, thread_id: threadId, reference: picked.reference, message }
  }

  const token = Deno.env.get('TELEGRAM_BOT_TOKEN')
  const chatId = Deno.env.get('TELEGRAM_CHAT_ID')
  if (!token || !chatId) {
    console.error('[TELEGRAM-VERSE] TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID missing')
    return { success: false, skipped: true, reason: 'telegram_not_configured' }
  }

  // Claim the slot before sending: a retry skips a 'sent' or in-flight slot,
  // so a ledger write failing after a successful send can never repost.
  const claim = await claimDailySlot(supabase, LEDGER, today, language, {
    reference: picked.reference,
    thread_id: threadId,
  })
  if (!claim.claimed) {
    if (claim.error) {
      console.error('[TELEGRAM-VERSE] ledger claim failed', claim.error)
      return { success: false, error: 'ledger_claim_failed' }
    }
    return { success: true, skipped: true, reason: claim.status === 'sent' ? 'already_posted_today' : 'post_in_progress' }
  }

  const sent = await sendTelegramMessage(token, chatId, message, threadId)
  await settleDailySlot(supabase, LEDGER, today, language, sent)

  if (!sent.ok) {
    console.error('[TELEGRAM-VERSE] send failed', { language, error: sent.error })
    return { success: false, error: sent.error }
  }

  console.log('[TELEGRAM-VERSE] posted', { date: today, language, thread_id: threadId, message_id: sent.messageId })
  return { success: true, language, reference: picked.reference, message_id: sent.messageId }
})
