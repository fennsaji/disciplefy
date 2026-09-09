/**
 * Pre-warms learning-path study guides on the Batch API, a slice at a time.
 *
 * Every learning-path lesson produces the same guide for every reader, so it is
 * worth generating each one deliberately rather than making the first reader
 * wait and pay. Batch costs half the streaming rate and answers within 24
 * hours, which is fine for work nobody is waiting on.
 *
 * Spending is governed by a monthly budget in system_config
 * (`prewarm_monthly_budget_usd`, editable from the admin dashboard). The job
 * takes only as many lessons as the remaining budget covers. When the month's
 * budget is gone it stops and waits; whatever it did not reach is generated on
 * demand, exactly as it would have been anyway.
 *
 * A standard study is two passes and the second reads the first, so a run is
 * two batches in sequence. This endpoint is a single `tick`, called on a
 * schedule by rs-backend:
 *
 *   - nothing in flight  -> pick lessons within budget, submit pass 1
 *   - pass 1 ended       -> build pass 2 from its results, submit pass 2
 *   - pass 2 ended       -> write the guides, record the spend, finish
 *   - still running      -> report and wait
 *
 * Only the batch id is persisted. Anthropic keeps results retrievable, so a
 * restart mid-run re-fetches them and carries on.
 */

import { createServiceRoleFunction } from '../_shared/core/function-factory.ts'
import { AnthropicBatchClient, type BatchRequest } from '../_shared/services/llm-clients/anthropic-batch.ts'
import {
  createStandardPass1Prompt,
  createStandardPass2Prompt,
  combineStandardPasses,
} from '../_shared/services/llm-utils/standard-multipass.ts'
import { calculateOptimalTokens } from '../_shared/services/llm-utils/prompt-builder.ts'
import { getLanguageConfig } from '../_shared/services/llm-config/language-configs.ts'
import type { LLMGenerationParams } from '../_shared/services/llm-types.ts'

const MODEL = 'claude-sonnet-4-5-20250929'
/** Batch pricing, per million tokens: half the streaming rate. */
const PRICE_PER_MTOK = { input: 1.5, output: 7.5 }
const DEFAULT_MONTHLY_BUDGET_USD = 20
const LANGUAGES = ['en', 'hi', 'ml'] as const
const STUDY_MODE = 'standard'

/** Both passes of one guide, from the measured shape of a standard study. */
const ESTIMATED_COST_PER_GUIDE =
  2 * ((6000 * PRICE_PER_MTOK.input + 3000 * PRICE_PER_MTOK.output) / 1_000_000)

interface Lesson {
  topic_id: string
  title: string
  description: string | null
  path_title: string
  path_description: string | null
  disciple_level: string
  /** Where the path sits in the catalogue, and the lesson within the path. */
  path_order: number
  topic_position: number
}

/**
 * `topicId_language` — the id Anthropic echoes back with each result.
 *
 * Anthropic requires `^[a-zA-Z0-9_-]{1,64}$`, so the separator is an
 * underscore: a UUID contains hyphens but never one of those.
 */
function customId(topicId: string, language: string): string {
  return `${topicId}_${language}`
}

function parseCustomId(id: string): { topicId: string; language: string } {
  const cut = id.lastIndexOf('_')
  return { topicId: id.slice(0, cut), language: id.slice(cut + 1) }
}

function extractJson(text: string): Record<string, unknown> {
  const start = text.indexOf('{')
  const end = text.lastIndexOf('}')
  if (start === -1 || end === -1) throw new Error('No JSON object in the response')
  return JSON.parse(text.slice(start, end + 1))
}

function paramsFor(lesson: Lesson, language: string): LLMGenerationParams {
  return {
    inputType: 'topic',
    inputValue: lesson.title,
    topicDescription: lesson.description ?? undefined,
    pathTitle: lesson.path_title,
    pathDescription: lesson.path_description ?? undefined,
    discipleLevel: lesson.disciple_level,
    language,
    studyMode: STUDY_MODE,
  }
}

/** The same hash the repository writes, so a title lookup also finds these rows. */
async function hashInput(language: string, value: string): Promise<string> {
  const normalized = value.toLowerCase().trim().replace(/\s+/g, ' ')
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(`topic:${language}:${STUDY_MODE}:${normalized}`),
  )
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

// deno-lint-ignore no-explicit-any -- the generated database types are not wired into functions
type Db = any

async function remainingBudgetUsd(db: Db): Promise<{ budget: number; spent: number; left: number }> {
  const { data: row } = await db
    .from('system_config')
    .select('value')
    .eq('key', 'prewarm_monthly_budget_usd')
    .eq('is_active', true)
    .maybeSingle()

  const configured = Number(row?.value)
  const budget = Number.isFinite(configured) && configured >= 0 ? configured : DEFAULT_MONTHLY_BUDGET_USD

  const { data: spent } = await db.rpc('prewarm_spend_this_month')
  const spentUsd = Number(spent ?? 0)

  return { budget, spent: spentUsd, left: Math.max(0, budget - spentUsd) }
}

/**
 * Lessons still missing a guide, in catalogue order across every language.
 *
 * Ordered by path, then position within the path, then language, so a budget
 * that only covers part of the catalogue covers the *first* lessons in all
 * three languages rather than the whole of English. Readers of every language
 * reach a cached guide at the same point in their path.
 */
async function lessonsNeedingGuides(db: Db, limit: number): Promise<Array<{ lesson: Lesson; language: string }>> {
  const wanted: Array<{ lesson: Lesson; language: string }> = []

  for (const language of LANGUAGES) {
    const { data, error } = await db.rpc('prewarm_missing_lessons', {
      p_language: language,
      p_study_mode: STUDY_MODE,
      p_limit: limit,
    })
    if (error) throw new Error(`Could not list ${language} lessons: ${error.message}`)
    for (const lesson of (data ?? []) as Lesson[]) wanted.push({ lesson, language })
  }

  const languageOrder = (language: string) => LANGUAGES.indexOf(language as typeof LANGUAGES[number])

  wanted.sort((a, b) =>
    (a.lesson.path_order ?? 0) - (b.lesson.path_order ?? 0) ||
    (a.lesson.topic_position ?? 0) - (b.lesson.topic_position ?? 0) ||
    a.lesson.title.localeCompare(b.lesson.title) ||
    languageOrder(a.language) - languageOrder(b.language)
  )

  return wanted.slice(0, limit)
}

/**
 * Every lesson still missing a guide, keyed by custom id.
 *
 * Built once per tick: looking each one up individually inside the results loop
 * meant a round trip per guide, hundreds of them in a full run.
 */
async function lessonIndex(db: Db): Promise<Map<string, Lesson>> {
  const index = new Map<string, Lesson>()
  for (const language of LANGUAGES) {
    const { data } = await db.rpc('prewarm_missing_lessons', {
      p_language: language,
      p_study_mode: STUDY_MODE,
      p_limit: 5000,
    })
    for (const lesson of (data ?? []) as Lesson[]) {
      index.set(customId(lesson.topic_id, language), lesson)
    }
  }
  return index
}

function buildRequest(lesson: Lesson, language: string, pass1?: Record<string, unknown>): BatchRequest {
  const config = getLanguageConfig(language)!
  const params = paramsFor(lesson, language)
  const prompt = pass1
    ? createStandardPass2Prompt(params, config, pass1 as never)
    : createStandardPass1Prompt(params, config)

  return {
    customId: customId(lesson.topic_id, language),
    model: MODEL,
    maxTokens: calculateOptimalTokens(params, config),
    temperature: config.temperature,
    system: [
      { type: 'text', text: prompt.sharedSystem, cache_control: { type: 'ephemeral' } },
      { type: 'text', text: prompt.passSystem, cache_control: { type: 'ephemeral' } },
    ],
    userMessage: prompt.userMessage,
  }
}

/** Records what a run spent, so the next one knows and the costs page shows it. */
async function recordSpend(db: Db, inputTokens: number, outputTokens: number, guides: number): Promise<number> {
  const costUsd = (inputTokens * PRICE_PER_MTOK.input + outputTokens * PRICE_PER_MTOK.output) / 1_000_000
  const { error } = await db.from('usage_logs').insert({
    tier: 'system',
    feature_name: 'prewarm',
    operation_type: 'create',
    tokens_consumed: 0,
    llm_provider: 'anthropic',
    llm_model: MODEL,
    llm_input_tokens: inputTokens,
    llm_output_tokens: outputTokens,
    llm_cost_usd: costUsd,
    request_metadata: { guides, pricing: 'batch' },
  })
  if (error) console.error('[prewarm] could not record spend:', error.message)
  return costUsd
}

createServiceRoleFunction(async (_req, supabase) => {
  const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
  if (!apiKey) {
    return { success: false, error: 'ANTHROPIC_API_KEY is not set; refusing to pre-warm' }
  }

  const client = new AnthropicBatchClient(apiKey)

  // Is a batch already in flight?
  const { data: inFlight } = await supabase
    .from('prewarm_runs')
    .select('*')
    .eq('status', 'submitted')
    .maybeSingle()

  // --- Nothing outstanding: start a run, if the budget allows one. ---
  if (!inFlight) {
    const budget = await remainingBudgetUsd(supabase)
    const affordable = Math.floor(budget.left / ESTIMATED_COST_PER_GUIDE)

    if (affordable <= 0) {
      console.log(`[prewarm] month's budget spent ($${budget.spent.toFixed(2)} of $${budget.budget.toFixed(2)})`)
      return {
        success: true,
        action: 'waiting_for_budget',
        budget_usd: budget.budget,
        spent_usd: budget.spent,
      }
    }

    const wanted = await lessonsNeedingGuides(supabase, affordable)
    if (wanted.length === 0) {
      console.log('[prewarm] every learning-path lesson already has a guide')
      return { success: true, action: 'nothing_to_do' }
    }

    const requests = wanted.map(({ lesson, language }) => buildRequest(lesson, language))
    const batchId = await client.submit(requests)

    await supabase.from('prewarm_runs').insert({
      batch_id: batchId,
      phase: 'pass1',
      request_count: requests.length,
      note: `${wanted.length} lessons, about $${(wanted.length * ESTIMATED_COST_PER_GUIDE).toFixed(2)}`,
    })

    console.log(`[prewarm] submitted pass 1 for ${requests.length} lessons as ${batchId}`)
    return {
      success: true,
      action: 'submitted_pass1',
      batch_id: batchId,
      lessons: requests.length,
      budget_left_usd: budget.left,
    }
  }

  // --- A batch is outstanding: has it finished? ---
  const status = await client.status(inFlight.batch_id)
  if (status.processingStatus !== 'ended') {
    console.log(`[prewarm] ${inFlight.batch_id} still running: ${JSON.stringify(status.counts)}`)
    return { success: true, action: 'in_progress', batch_id: inFlight.batch_id, counts: status.counts }
  }

  let inputTokens = 0
  let outputTokens = 0
  const failures: string[] = []

  // --- Pass 1 finished: build pass 2 from its results. ---
  if (inFlight.phase === 'pass1') {
    const pass2Requests: BatchRequest[] = []
    const lessons = await lessonIndex(supabase)

    for await (const result of client.results(inFlight.batch_id)) {
      const { topicId, language } = parseCustomId(result.customId)
      if (result.error || !result.content) {
        failures.push(`${topicId} ${language}: ${result.error ?? 'no content'}`)
        continue
      }
      inputTokens += result.inputTokens ?? 0
      outputTokens += result.outputTokens ?? 0

      const lesson = lessons.get(result.customId)
      if (!lesson) continue

      try {
        pass2Requests.push(buildRequest(lesson, language, extractJson(result.content)))
      } catch (error) {
        failures.push(`${topicId} ${language}: ${(error as Error).message}`)
      }
    }

    await recordSpend(supabase, inputTokens, outputTokens, 0)

    if (pass2Requests.length === 0) {
      await supabase.from('prewarm_runs')
        .update({ status: 'failed', note: `pass 1 produced nothing usable: ${failures.slice(0, 3).join('; ')}`, updated_at: new Date().toISOString() })
        .eq('id', inFlight.id)
      return { success: false, action: 'pass1_empty', failures: failures.length }
    }

    const batchId = await client.submit(pass2Requests)
    await supabase.from('prewarm_runs')
      .update({
        batch_id: batchId,
        // A finished guide needs both halves, so remember where pass 1 lives.
        pass1_batch_id: inFlight.batch_id,
        phase: 'pass2',
        request_count: pass2Requests.length,
        updated_at: new Date().toISOString(),
      })
      .eq('id', inFlight.id)

    console.log(`[prewarm] submitted pass 2 for ${pass2Requests.length} lessons as ${batchId}`)
    return { success: true, action: 'submitted_pass2', batch_id: batchId, lessons: pass2Requests.length }
  }

  // --- Pass 2 finished: write the guides. ---
  // A guide is both halves joined, so read pass 1's results back first. Its
  // tokens were already paid for and recorded when that pass completed.
  const pass1ByLesson = new Map<string, Record<string, unknown>>()
  if (inFlight.pass1_batch_id) {
    for await (const earlier of client.results(inFlight.pass1_batch_id)) {
      if (!earlier.content) continue
      try {
        pass1ByLesson.set(earlier.customId, extractJson(earlier.content))
      } catch {
        // Reported already when pass 1 completed; the lesson is simply skipped.
      }
    }
  }

  const lessons = await lessonIndex(supabase)
  let written = 0

  for await (const result of client.results(inFlight.batch_id)) {
    const { topicId, language } = parseCustomId(result.customId)
    if (result.error || !result.content) {
      failures.push(`${topicId} ${language}: ${result.error ?? 'no content'}`)
      continue
    }
    inputTokens += result.inputTokens ?? 0
    outputTokens += result.outputTokens ?? 0

    try {
      const lesson = lessons.get(result.customId)
      if (!lesson) continue

      const pass1 = pass1ByLesson.get(result.customId)
      if (!pass1) {
        failures.push(`${topicId} ${language}: pass 1 result missing, cannot join the guide`)
        continue
      }

      const pass2 = extractJson(result.content)
      const guide = combineStandardPasses(
        {
          summary: String(pass1.summary ?? ''),
          context: String(pass1.context ?? ''),
          passage: String(pass1.passage ?? ''),
          interpretationPart1: String(pass1.interpretationPart1 ?? ''),
        },
        pass2 as never,
      )

      const { error } = await supabase.from('study_guides').insert({
        input_type: 'topic',
        input_value: lesson.title,
        input_value_hash: await hashInput(language, lesson.title),
        language,
        study_mode: STUDY_MODE,
        topic_id: topicId,
        summary: guide.summary,
        interpretation: guide.interpretation,
        context: guide.context,
        passage: guide.passage ?? null,
        related_verses: guide.relatedVerses,
        reflection_questions: guide.reflectionQuestions,
        prayer_points: guide.prayerPoints,
        updated_at: new Date().toISOString(),
      })

      // A conflict means something generated this lesson while the batch ran.
      // Either guide is fine, so the insert is allowed to lose quietly.
      if (error && error.code !== '23505') failures.push(`${topicId} ${language}: ${error.message}`)
      else if (!error) written += 1
    } catch (error) {
      failures.push(`${topicId} ${language}: ${(error as Error).message}`)
    }
  }

  const costUsd = await recordSpend(supabase, inputTokens, outputTokens, written)

  await supabase.from('prewarm_runs')
    .update({
      status: 'completed',
      guides_written: written,
      note: failures.length > 0 ? `${failures.length} did not complete` : null,
      updated_at: new Date().toISOString(),
    })
    .eq('id', inFlight.id)

  console.log(`[prewarm] wrote ${written} guides for $${costUsd.toFixed(2)}`)
  if (failures.length > 0) {
    console.log(`[prewarm] ${failures.length} lessons did not complete; they stay on the streaming path`)
  }

  return {
    success: true,
    action: 'completed',
    guides_written: written,
    cost_usd: Number(costUsd.toFixed(4)),
    failures: failures.length,
  }
}, { allowedMethods: ['POST', 'GET'] })
