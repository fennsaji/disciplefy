/**
 * Telegram Bot API helpers shared by the channel jobs.
 *
 * Forum topics: each post kind goes to a topic (message_thread_id) per
 * language, looked up in `public.telegram_topics`. A missing mapping posts to
 * the group without a topic rather than failing.
 */

// deno-lint-ignore no-explicit-any
type SupabaseLike = any

export type TelegramPostKind = 'study_post' | 'daily_verse'

export interface TelegramTopicRow {
  kind: string
  language: string
  thread_id: number | string | null
}

export interface TelegramSendResult {
  ok: boolean
  messageId: number | null
  error: string | null
}

const TELEGRAM_API = 'https://api.telegram.org'

/** Picks the thread id for a kind/language from mapping rows; null when unmapped. */
export function pickThreadId(
  rows: TelegramTopicRow[] | null | undefined,
  kind: TelegramPostKind,
  language: string,
): number | null {
  const row = rows?.find((r) => r.kind === kind && r.language === language)
  const id = Number(row?.thread_id)
  return Number.isInteger(id) && id > 0 ? id : null
}

/** Reads the topic for a kind/language. Logs and returns null when missing or unreadable. */
export async function resolveTelegramThreadId(
  supabase: SupabaseLike,
  kind: TelegramPostKind,
  language: string,
): Promise<number | null> {
  const { data, error } = await supabase
    .from('telegram_topics')
    .select('kind, language, thread_id')
    .eq('kind', kind)
    .eq('language', language)
  if (error) {
    console.warn('[TELEGRAM] topic lookup failed, posting without topic', { kind, language, error: error.message })
    return null
  }
  const threadId = pickThreadId(data, kind, language)
  if (threadId === null) {
    console.warn('[TELEGRAM] no topic mapped, posting without topic', { kind, language })
  }
  return threadId
}

/** The sendMessage body. Plain text: titles carry characters Markdown would need escaped. */
export function buildSendMessageBody(
  chatId: string,
  text: string,
  threadId: number | null,
): Record<string, unknown> {
  const body: Record<string, unknown> = {
    chat_id: chatId,
    text,
    disable_web_page_preview: false,
  }
  if (threadId !== null) body.message_thread_id = threadId
  return body
}

export async function sendTelegramMessage(
  token: string,
  chatId: string,
  text: string,
  threadId: number | null,
): Promise<TelegramSendResult> {
  try {
    const res = await fetch(`${TELEGRAM_API}/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(buildSendMessageBody(chatId, text, threadId)),
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
