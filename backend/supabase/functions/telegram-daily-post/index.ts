/**
 * Telegram Daily Post — Scheduled Background Job
 *
 * Posts one lesson a day to the official Telegram channel: the topic title, the
 * Discipler teaser, and a link to that topic's blog article.
 *
 * The channel walks the catalogue independently of any fellowship — learning
 * path display order, then topic position — and `telegram_daily_posts` is both
 * the record and the cursor. A lesson with no published blog article is skipped
 * by the picker rather than posted with a dead link.
 *
 * Teasers come from the shared teaser service, so a lesson already teased for a
 * fellowship costs nothing here; only a lesson no one has seen yet is generated.
 *
 * Schedule: daily via pg_cron (see 20260908000004_schedule_telegram_daily_post.sql).
 * Env: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID.
 */

import { createServiceRoleFunction } from '../_shared/core/function-factory.ts'
import { getServiceContainer } from '../_shared/core/services.ts'
import { getOrCreateTeaser } from '../_shared/services/teaser-service.ts'
import { buildTelegramMessage } from './message.ts'

/**
 * Audience id for the variant picker. A constant, so the channel keeps one
 * voice across lessons instead of hopping between stored wordings.
 */
const TELEGRAM_AUDIENCE = 'telegram-official-channel'

const TELEGRAM_API = 'https://api.telegram.org'

interface TelegramSendResult {
  ok: boolean
  messageId: number | null
  error: string | null
}

async function sendToTelegram(token: string, chatId: string, text: string): Promise<TelegramSendResult> {
  try {
    const res = await fetch(`${TELEGRAM_API}/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        // The message is plain text on purpose: topic titles carry apostrophes
        // and em dashes that would have to be escaped for Markdown or HTML,
        // and a single missed escape drops the whole post.
        disable_web_page_preview: false,
      }),
    })
    const payload = await res.json().catch(() => null)
    if (!res.ok || !payload?.ok) {
      return { ok: false, messageId: null, error: payload?.description ?? `HTTP ${res.status}` }
    }
    return { ok: true, messageId: payload.result?.message_id ?? null, error: null }
  } catch (err) {
    return { ok: false, messageId: null, error: err instanceof Error ? err.message : String(err) }
  }
}

createServiceRoleFunction(async (req, supabase) => {
  const token = Deno.env.get('TELEGRAM_BOT_TOKEN')
  const chatId = Deno.env.get('TELEGRAM_CHAT_ID')

  // A dry run composes the post and returns it without sending or recording,
  // so the wording can be checked against a real lesson before going live.
  let dryRun = false
  let language = 'en'
  try {
    const body = await req.json()
    dryRun = body?.dry_run === true
    if (typeof body?.language === 'string') language = body.language
  } catch { /* no body: a scheduled run */ }

  const today = new Date().toISOString().slice(0, 10)

  // Idempotency: a second run on the same day must not post twice, whatever
  // retried it — pg_cron, a manual call, or a redeploy.
  const { data: existing } = await supabase
    .from('telegram_daily_posts')
    .select('id, topic_id, blog_slug')
    .eq('post_date', today)
    .eq('language', language)
    .eq('status', 'sent')
    .maybeSingle()

  if (existing && !dryRun) {
    console.log('[TELEGRAM-DAILY] already posted today', { date: today, topic_id: existing.topic_id })
    return { success: true, skipped: true, reason: 'already_posted_today', topic_id: existing.topic_id }
  }

  const { data: next, error: pickError } = await supabase
    .rpc('next_telegram_topic', { p_language: language })
    .maybeSingle()

  if (pickError) {
    console.error('[TELEGRAM-DAILY] picker failed', pickError.message)
    return { success: false, error: pickError.message }
  }
  if (!next) {
    // Either every lesson has been posted, or none of the remaining ones has a
    // published article yet. Both are a quiet no-op, not a failure.
    console.log('[TELEGRAM-DAILY] nothing due', { language })
    return { success: true, skipped: true, reason: 'no_topic_with_published_article' }
  }

  const services = await getServiceContainer()
  const teaser = await getOrCreateTeaser(supabase, services.llmService, {
    topicId: next.topic_id,
    topicTitle: next.topic_title,
    pathTitle: next.path_title,
    language: language as 'en' | 'hi' | 'ml',
    summary: next.topic_description,
    // The article's study guide, when it has one. The fellowship cron passes
    // these too, so whichever surface generates a lesson's teaser first
    // produces the same wording quality — and the other reuses it.
    verse: next.verse ?? undefined,
    question: next.question ?? undefined,
  }, TELEGRAM_AUDIENCE)

  const message = buildTelegramMessage({
    topicTitle: next.topic_title,
    hook: teaser.hook,
    body: teaser.body,
    blogSlug: next.blog_slug,
  })

  if (dryRun) {
    return {
      success: true, dry_run: true, topic_id: next.topic_id, topic_title: next.topic_title,
      blog_slug: next.blog_slug, teaser_cached: teaser.cached, message,
    }
  }

  // Checked here rather than up front: with nothing due, or the day already
  // posted, a missing token is not this run's problem.
  if (!token || !chatId) {
    console.error('[TELEGRAM-DAILY] TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID missing')
    return { success: false, skipped: true, reason: 'telegram_not_configured', topic_id: next.topic_id }
  }

  const sent = await sendToTelegram(token, chatId, message)

  // Recorded either way: a failed row keeps the day visible without consuming
  // the lesson, so the next run retries the same one.
  const { error: ledgerError } = await supabase.from('telegram_daily_posts').upsert({
    post_date: today,
    topic_id: next.topic_id,
    learning_path_id: next.learning_path_id,
    blog_slug: next.blog_slug,
    language,
    message_id: sent.messageId,
    status: sent.ok ? 'sent' : 'failed',
    error: sent.error,
  }, { onConflict: 'post_date,language' })

  if (ledgerError) {
    console.error('[TELEGRAM-DAILY] ledger write failed', ledgerError.message)
  }

  if (!sent.ok) {
    console.error('[TELEGRAM-DAILY] send failed', { topic_id: next.topic_id, error: sent.error })
    return { success: false, topic_id: next.topic_id, error: sent.error }
  }

  console.log('[TELEGRAM-DAILY] posted', {
    date: today, topic_id: next.topic_id, blog_slug: next.blog_slug,
    teaser_cached: teaser.cached, message_id: sent.messageId,
  })
  return {
    success: true, topic_id: next.topic_id, topic_title: next.topic_title,
    blog_slug: next.blog_slug, teaser_cached: teaser.cached, message_id: sent.messageId,
  }
})
