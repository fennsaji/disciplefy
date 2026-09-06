// backend/supabase/functions/fellowship-posts/daily-teaser.ts
/**
 * POST /fellowship-posts/daily-teaser  { fellowship_id, topic_title, path_title, language, summary, verse?, question? }
 * Internal only (X-Internal-Api-Key). Called by the rs-backend cron before it posts a
 * fellowship's daily study — returns a short teaser so the caller can lead with it instead
 * of its own template. Any failure returns 503 so the caller falls back to its template.
 */
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import {
  buildDailyTeaserSystemPrompt, buildDailyTeaserUserMessage, parseDailyTeaserOutput,
} from '../_shared/prompts/discipler-prompt.ts'
import { isDisciplerGloballyEnabled } from '../_shared/services/discipler-service.ts'
import { isInternalCaller } from './discipler-reply.ts'

interface DailyTeaserRequest {
  fellowship_id: string
  topic_title: string
  path_title: string
  language: 'en' | 'hi' | 'ml'
  summary: string
  verse?: string
  question?: string
}

const LANGUAGES = new Set(['en', 'hi', 'ml'])

function unavailable(): Response {
  return new Response(JSON.stringify({ error: 'TEASER_UNAVAILABLE' }), {
    status: 503,
    headers: { 'Content-Type': 'application/json' },
  })
}

function validate(body: unknown): DailyTeaserRequest {
  const b = body as Partial<DailyTeaserRequest> | null
  if (!b || typeof b !== 'object') throw new AppError('VALIDATION_ERROR', 'Request body must be a JSON object', 400)
  if (typeof b.fellowship_id !== 'string' || !b.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (typeof b.topic_title !== 'string' || !b.topic_title.trim()) throw new AppError('VALIDATION_ERROR', 'topic_title is required', 400)
  if (typeof b.path_title !== 'string' || !b.path_title.trim()) throw new AppError('VALIDATION_ERROR', 'path_title is required', 400)
  if (typeof b.language !== 'string' || !LANGUAGES.has(b.language)) throw new AppError('VALIDATION_ERROR', 'language must be en, hi or ml', 400)
  if (typeof b.summary !== 'string' || !b.summary.trim()) throw new AppError('VALIDATION_ERROR', 'summary is required', 400)
  if (b.verse !== undefined && typeof b.verse !== 'string') throw new AppError('VALIDATION_ERROR', 'verse must be a string', 400)
  if (b.question !== undefined && typeof b.question !== 'string') throw new AppError('VALIDATION_ERROR', 'question must be a string', 400)
  return {
    fellowship_id: b.fellowship_id,
    topic_title: b.topic_title.trim(),
    path_title: b.path_title.trim(),
    language: b.language as 'en' | 'hi' | 'ml',
    summary: b.summary.trim(),
    verse: b.verse?.trim() || undefined,
    question: b.question?.trim() || undefined,
  }
}

export async function handleDailyTeaser(req: Request, services: ServiceContainer): Promise<Response> {
  let ctx: { userId: string } | null = null
  try { ctx = await services.authService.getUserContext(req) as { userId: string } } catch { ctx = null }
  if (!isInternalCaller(ctx, req.headers.get('Authorization'))) {
    throw new AppError('PERMISSION_DENIED', 'Internal callers only', 403)
  }

  let rawBody: unknown
  try { rawBody = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  const input = validate(rawBody)

  const db = services.supabaseServiceClient

  try {
    const globalEnabled = await isDisciplerGloballyEnabled(db)
    if (!globalEnabled) return unavailable()

    const result = await services.llmService.generateDailyTeaser({
      systemMessage: buildDailyTeaserSystemPrompt(),
      userMessage: buildDailyTeaserUserMessage({
        topicTitle: input.topic_title, pathTitle: input.path_title, language: input.language,
        summary: input.summary, verse: input.verse, question: input.question,
      }),
    })
    const out = parseDailyTeaserOutput(result.content)

    console.log('[fellowship-posts/daily-teaser] generated', {
      fellowship_id: input.fellowship_id, model: result.model,
      hook_length: out.hook.length, body_length: out.body.length,
    })

    return new Response(JSON.stringify({ hook: out.hook, body: out.body, model: result.model }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('[fellowship-posts/daily-teaser] failed', {
      fellowship_id: input.fellowship_id,
      error: err instanceof Error ? err.message : String(err),
    })
    return unavailable()
  }
}
