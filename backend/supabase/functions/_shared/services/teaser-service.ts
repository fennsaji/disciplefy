// backend/supabase/functions/_shared/services/teaser-service.ts
/**
 * One place that turns a lesson into a Discipler teaser, and the only place
 * allowed to pay for one.
 *
 * The teaser prompt takes the lesson and nothing about who is reading it, so a
 * teaser generated for a fellowship is equally good for another fellowship or
 * for the Telegram channel. Every caller goes through here, and a lesson that
 * already has a teaser is never generated again — one LLM call per lesson and
 * language, for every surface and for the life of that lesson.
 */
import {
  buildDailyTeaserSystemPrompt, buildDailyTeaserUserMessage, parseDailyTeaserOutput,
} from '../prompts/discipler-prompt.ts'

export type TeaserLanguage = 'en' | 'hi' | 'ml'

export interface TeaserLesson {
  /** recommended_topics.id when the caller knows it; otherwise omitted. */
  topicId?: string
  topicTitle: string
  pathTitle: string
  language: TeaserLanguage
  summary: string
  verse?: string
  question?: string
}

export interface Teaser {
  hook: string
  body: string
  model: string | null
  /** True when nothing was generated for this call. */
  cached: boolean
}

/**
 * Slot a freshly generated wording is stored under.
 *
 * A lesson is generated once and then reused everywhere, so in practice a topic
 * has one row. The column exists so extra wordings can be seeded later (by an
 * admin, or a backfill) without a migration: readers spread across whatever
 * rows are present.
 */
export const FIRST_VARIANT = 0

/**
 * Cache key for a lesson: the topic id when the caller knows it, else a hash of
 * the titles it did send.
 *
 * The summary is deliberately not part of the key — an edited summary should
 * keep serving the teaser it already has rather than silently pay for a new one.
 */
export async function teaserCacheKey(lesson: {
  topicId?: string
  pathTitle: string
  topicTitle: string
}): Promise<string> {
  if (lesson.topicId) return lesson.topicId
  const seed = `${lesson.pathTitle.trim().toLowerCase()}|${lesson.topicTitle.trim().toLowerCase()}`
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(seed))
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

/**
 * Stable index into whatever wordings a lesson has, so a given group or channel
 * always reads the same one rather than switching between refreshes.
 *
 * Returns 0 when [count] is 0 or 1, which is the usual case.
 */
export function variantForAudience(audienceId: string, count: number): number {
  if (count <= 1) return 0
  let hash = 0
  for (let i = 0; i < audienceId.length; i++) {
    hash = (hash * 31 + audienceId.charCodeAt(i)) % 1_000_000_007
  }
  return hash % count
}

// deno-lint-ignore no-explicit-any
type Db = any
// deno-lint-ignore no-explicit-any
type Llm = any

/**
 * Returns the teaser for [lesson], generating one only when the chosen slot is
 * empty.
 *
 * [audienceId] decides which of the stored wordings comes back — pass the
 * fellowship id for a group, or a fixed string for a broadcast channel so that
 * channel reads consistently.
 *
 * Throws only when there is no teaser to return: a cache write that fails still
 * yields the generated teaser, because the caller has a post to send either way.
 */
export async function getOrCreateTeaser(
  db: Db,
  llmService: Llm,
  lesson: TeaserLesson,
  audienceId: string,
): Promise<Teaser> {
  const topicKey = await teaserCacheKey(lesson)

  // Every wording this lesson has, not just one slot: a teaser generated for a
  // fellowship must serve the Telegram channel too, or the same lesson gets
  // paid for once per surface.
  const { data: rows } = await db
    .from('discipler_teaser_cache')
    .select('id, hook, body, model, use_count, variant')
    .eq('topic_key', topicKey)
    .eq('language', lesson.language)
    .order('variant', { ascending: true })

  if (rows && rows.length > 0) {
    const chosen = rows[variantForAudience(audienceId, rows.length)]

    // Best-effort usage stamp: a failed counter must not cost the caller its teaser.
    db.from('discipler_teaser_cache')
      .update({ use_count: (chosen.use_count ?? 0) + 1, last_used_at: new Date().toISOString() })
      .eq('id', chosen.id)
      .then(undefined, () => {})

    console.log('[teaser-service] cache hit', {
      topic_key: topicKey, variant: chosen.variant, wordings: rows.length, audience: audienceId,
    })
    return { hook: chosen.hook, body: chosen.body, model: chosen.model, cached: true }
  }

  const result = await llmService.generateDailyTeaser({
    systemMessage: buildDailyTeaserSystemPrompt(),
    userMessage: buildDailyTeaserUserMessage({
      topicTitle: lesson.topicTitle, pathTitle: lesson.pathTitle, language: lesson.language,
      summary: lesson.summary, verse: lesson.verse, question: lesson.question,
    }),
  }, lesson.language)
  const out = parseDailyTeaserOutput(result.content)

  // Store before returning so the next surface on this lesson pays nothing. A
  // conflict means another request filled the slot first — either wording is
  // fine, so the insert is allowed to lose quietly.
  const { error: cacheError } = await db.from('discipler_teaser_cache').insert({
    topic_key: topicKey,
    language: lesson.language,
    variant: FIRST_VARIANT,
    topic_title: lesson.topicTitle,
    path_title: lesson.pathTitle,
    hook: out.hook,
    body: out.body,
    model: result.model,
    use_count: 1,
    last_used_at: new Date().toISOString(),
  })
  if (cacheError && cacheError.code !== '23505') {
    console.error('[teaser-service] cache write failed', {
      topic_key: topicKey, error: cacheError.message,
    })
  }

  console.log('[teaser-service] generated', {
    topic_key: topicKey, audience: audienceId, model: result.model,
  })
  return { hook: out.hook, body: out.body, model: result.model, cached: false }
}
