// backend/supabase/functions/fellowship-posts/discipler-reply.ts
/**
 * POST /fellowship-posts/discipler-reply  { queue_id }
 * Internal only (X-Internal-Api-Key or service-role bearer). Called by rs-backend discipler_reply_worker.
 */
import type { SupabaseClient } from '@supabase/supabase-js'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { determineAction, validateInputSecurity } from '../_shared/services/llm-utils/security-validator.ts'
import { buildDisciplerSystemPrompt, buildDisciplerUserMessage, parseDisciplerOutput, type DisciplerOutput } from '../_shared/prompts/discipler-prompt.ts'
import { classifyComment, classifyPost, DISCIPLER_SYSTEM_USER_ID, DISCIPLER_USER_ID } from '../_shared/utils/discipler.ts'
import { isDisciplerGloballyEnabled, loadFellowshipDiscipler, pushMentors, pushUsers, reactAsDiscipler, recordActivity } from '../_shared/services/discipler-service.ts'

const USER_DAILY_LIMIT = 10
const FELLOWSHIP_DAILY_LIMIT = 100
const CONTEXT_CHARS = 4800 // ≈1,200 tokens

export function isInternalCaller(userContext: { userId: string } | null, authHeader: string | null): boolean {
  if (userContext?.userId === DISCIPLER_SYSTEM_USER_ID) return true
  const srk = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  return !!srk && authHeader === `Bearer ${srk}`
}

export function buildGuideAttachment(
  found: { id: string; title: string } | null,
  req: { input_type: 'topic' | 'scripture'; input_value: string },
  language: string,
) {
  return {
    study_guide_id: found?.id ?? null,
    guide_title: found?.title ?? req.input_value,
    guide_input_type: req.input_type,
    guide_input_value: req.input_value,
    guide_language: language,
  }
}

async function requireInternal(req: Request, services: ServiceContainer): Promise<void> {
  let ctx: { userId: string } | null = null
  try { ctx = await services.authService.getUserContext(req) as { userId: string } } catch { ctx = null }
  if (!isInternalCaller(ctx, req.headers.get('Authorization'))) {
    throw new AppError('PERMISSION_DENIED', 'Internal callers only', 403)
  }
}

async function displayName(db: SupabaseClient, userId: string): Promise<string> {
  try {
    const { data } = await db.auth.admin.getUserById(userId)
    const u = data?.user
    return u?.user_metadata?.full_name ?? u?.user_metadata?.name ?? u?.user_metadata?.display_name ?? 'A member'
  } catch { return 'A member' }
}

async function markQueue(db: SupabaseClient, queueId: string, status: string, lastError?: string): Promise<void> {
  const update: Record<string, unknown> = { status, last_error: lastError ?? null, updated_at: new Date().toISOString() }
  if (status === 'pending') update.run_after = new Date(Date.now() + 2 * 60_000).toISOString()
  await db.from('discipler_reply_queue').update(update).eq('id', queueId)
}

async function findCachedGuide(services: ServiceContainer, db: SupabaseClient, req: { input_type: string; input_value: string }, language: string): Promise<{ id: string; title: string } | null> {
  const normalized = req.input_value.toLowerCase().trim().replace(/\s+/g, ' ')
  const hash = await services.securityValidator.hashSensitiveData(`${req.input_type}:${language}:standard:${normalized}`)
  const { data } = await db.from('study_guides').select('id, input_value').eq('input_type', req.input_type)
    .eq('input_value_hash', hash).eq('language', language).eq('study_mode', 'standard').maybeSingle()
  return data ? { id: data.id as string, title: data.input_value as string } : null
}

export async function handleDisciplerReply(req: Request, services: ServiceContainer): Promise<Response> {
  await requireInternal(req, services)
  let body: { queue_id: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.queue_id) throw new AppError('VALIDATION_ERROR', 'queue_id is required', 400)

  const db = services.supabaseServiceClient
  const { data: q } = await db.from('discipler_reply_queue').select('*').eq('id', body.queue_id).maybeSingle()
  if (!q) throw new AppError('NOT_FOUND', 'Queue row not found', 404)
  if (q.status !== 'pending' && q.status !== 'processing') {
    return json({ status: q.status })
  }
  await db.from('discipler_reply_queue').update({ status: 'processing', attempts: (q.attempts ?? 0) + 1 }).eq('id', q.id)

  const done = async (status: string, extra: Record<string, unknown> = {}, err?: string) => {
    await markQueue(db, q.id, status, err)
    return json({ status, ...extra })
  }

  // Load post, optional comment, fellowship settings
  const [{ data: post }, settings, globalEnabled] = await Promise.all([
    db.from('fellowship_posts').select('id, fellowship_id, author_user_id, content, post_type, topic_id, topic_title, reaction_counts, is_deleted').eq('id', q.post_id).maybeSingle(),
    loadFellowshipDiscipler(db, q.fellowship_id),
    isDisciplerGloballyEnabled(db),
  ])
  if (!post || post.is_deleted || !settings) return done('skipped_gate')

  let askerId: string = post.author_user_id
  let question: string = post.content
  if (q.comment_id) {
    const { data: c } = await db.from('fellowship_comments').select('author_user_id, content, is_deleted').eq('id', q.comment_id).maybeSingle()
    if (!c || c.is_deleted) return done('skipped_gate')
    askerId = c.author_user_id
    question = c.content
  }

  // Re-check gates
  const { data: mentorRows, error: mentorError } = await db.rpc('fellowship_mentor_ids', { p_fellowship_id: q.fellowship_id })
  if (mentorError) return done((q.attempts ?? 0) + 1 >= 3 ? 'failed' : 'pending', {}, 'mentor rpc: ' + mentorError.message)
  const mentorIds = new Set(((mentorRows ?? []) as { user_id: string }[]).map((r) => r.user_id))
  const decision = q.comment_id
    ? classifyComment({ content: question, authorUserId: askerId, settings, globalEnabled })
    : classifyPost({ content: question, postType: post.post_type, topicId: post.topic_id ?? null,
        authorIsMentor: mentorIds.has(askerId), authorUserId: askerId, settings, globalEnabled })
  if (!decision || decision.trigger === 'react') return done('skipped_gate')
  const trigger = decision.trigger

  // Injection
  const sec = validateInputSecurity(question)
  if (!sec.isValid && determineAction(sec.riskScore) === 'blocked') return done('skipped_injection')

  // Budget
  const { data: budget, error: budgetError } = await db.rpc('discipler_daily_budget', { p_fellowship_id: q.fellowship_id, p_user_id: askerId })
  if (budgetError) return done((q.attempts ?? 0) + 1 >= 3 ? 'failed' : 'pending', {}, 'budget rpc: ' + budgetError.message)
  const b = (budget as { user_count: number; fellowship_count: number }[] | null)?.[0]
  if (b && (b.user_count >= USER_DAILY_LIMIT || b.fellowship_count >= FELLOWSHIP_DAILY_LIMIT)) return done('skipped_budget')

  // Thread + context (non-critical: log and continue with empty context on error)
  const { data: threadRows, error: threadError } = await db.from('fellowship_comments').select('author_user_id, content, created_at')
    .eq('post_id', post.id).eq('is_deleted', false).eq('is_pending_review', false).order('created_at', { ascending: false }).limit(5)
  if (threadError) console.error('[discipler-reply] thread fetch error (non-critical):', threadError)
  const thread = await Promise.all(((threadRows ?? []) as { author_user_id: string; content: string }[]).reverse().map(async (c) => ({
    author: c.author_user_id === DISCIPLER_USER_ID ? 'Discipler' : await displayName(db, c.author_user_id),
    isMentor: mentorIds.has(c.author_user_id), content: c.content.slice(0, 400),
  })))
  const contextQuery = post.topic_title ?? question
  const { data: guideRows, error: guideError } = await db.rpc('discipler_related_guide', { p_query: contextQuery.slice(0, 200), p_language: settings.language })
  if (guideError) console.error('[discipler-reply] related guide RPC error (non-critical):', guideError)
  const g = (guideRows as { summary: string | null; interpretation: string | null }[] | null)?.[0]
  const guideContext = g ? `${g.summary ?? ''}\n${g.interpretation ?? ''}`.trim().slice(0, CONTEXT_CHARS) || null : null

  const askerName = await displayName(db, askerId)

  // Model
  let out: DisciplerOutput
  let usage: { inputTokens?: number; outputTokens?: number; costUsd?: number }
  let model: string
  try {
    const result = await services.llmService.generateDisciplerReply({
      systemMessage: buildDisciplerSystemPrompt(),
      userMessage: buildDisciplerUserMessage({ trigger, fellowshipLanguage: settings.language, question, askerName, guideContext, thread }),
    })
    out = parseDisciplerOutput(result.content, trigger)
    usage = result.usage as { inputTokens?: number; outputTokens?: number; costUsd?: number }
    model = result.model
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    return done((q.attempts ?? 0) + 1 >= 3 ? 'failed' : 'pending', {}, msg)
  }

  const log = async (action: 'reply' | 'react', commentId: string | null, guideAttached: boolean) => {
    await db.from('discipler_replies').insert({
      queue_id: q.id, post_id: post.id, comment_id: commentId, fellowship_id: q.fellowship_id, asked_by: askerId,
      trigger, action, reaction: out.reaction, guide_attached: guideAttached, language_detected: out.language, model,
      input_tokens: usage.inputTokens ?? 0, output_tokens: usage.outputTokens ?? 0, cost_usd: usage.costUsd ?? 0,
    })
  }

  if (out.action === 'react') {
    const counts = await reactAsDiscipler(db, { postId: post.id, fellowshipId: q.fellowship_id, reaction: out.reaction!, currentCounts: (post.reaction_counts as Record<string, number>) ?? {} })
    await log('react', null, false)
    await recordActivity(db, { fellowshipId: q.fellowship_id, kind: 'react', postId: post.id, reaction: out.reaction, language: out.language, summary: `Reacted ${out.reaction} to ${askerName}'s question`, pushNow: false })
    return done('done', { action: 'react', reaction_counts: counts })
  }

  // Reply (+ optional guide)
  let attachment: Record<string, unknown> = {}
  if (out.guide_request) {
    const found = await findCachedGuide(services, db, out.guide_request, settings.language)
    attachment = buildGuideAttachment(found, out.guide_request, settings.language)
  }
  const pending = settings.discipler_reply_mode === 'review'
  const { data: comment, error: insertError } = await db.from('fellowship_comments').insert({
    post_id: post.id, fellowship_id: q.fellowship_id, author_user_id: DISCIPLER_USER_ID, content: out.reply,
    is_pending_review: pending, ...attachment,
  }).select('id').single()
  if (insertError || !comment) {
    return done((q.attempts ?? 0) + 1 >= 3 ? 'failed' : 'pending', {}, insertError?.message ?? 'comment insert failed')
  }

  await log('reply', comment.id, !!out.guide_request)
  await recordActivity(db, {
    fellowshipId: q.fellowship_id, kind: pending ? 'draft' : 'reply', postId: post.id, commentId: comment.id,
    language: out.language, summary: `${pending ? 'Drafted a reply' : 'Replied'} to ${askerName}: ${question.slice(0, 80)}`, pushNow: true,
  })

  const data = { type: 'fellowship_discipler_activity', fellowship_id: q.fellowship_id, post_id: post.id, comment_id: comment.id }
  const p1 = pushMentors(db, q.fellowship_id,
    { title: pending ? `📝 Discipler drafted a reply in ${settings.name}` : `✨ Discipler replied to ${askerName} in ${settings.name}`, body: out.reply!.slice(0, 80) },
    data, { respectMute: true })
  const p2 = pending ? Promise.resolve() : pushUsers(db, [askerId],
    { title: '✨ Discipler replied to your question', body: out.reply!.slice(0, 80) },
    { type: 'fellowship_discipler_reply', fellowship_id: q.fellowship_id, post_id: post.id, comment_id: comment.id })
  if (typeof EdgeRuntime !== 'undefined') EdgeRuntime.waitUntil(Promise.all([p1, p2]))

  return done('done', { action: 'reply', comment_id: comment.id, pending })
}

function json(data: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify({ success: true, data }), { status, headers: { 'Content-Type': 'application/json' } })
}
