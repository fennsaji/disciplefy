/**
 * Fills the study cache for the whole learning-path catalogue, once, on the
 * Batch API at half price.
 *
 * Every catalogue lesson produces the same guide for every user, so it is worth
 * generating each one deliberately rather than making the first reader wait and
 * pay. Guides are written with `topic_id` set, which is what the app looks them
 * up by, so a lesson opened in any language finds the guide whatever title it
 * arrived under.
 *
 * A standard study is two passes and the second depends on the first, so this
 * runs as two batch rounds: every pass 1 together, then every pass 2 built from
 * those results. Anything that fails is reported by topic and language and left
 * for the streaming path to make on demand.
 *
 * Dry run by default. It prints what it would submit and what that costs, and
 * touches neither Anthropic nor the database:
 *
 *   deno run --allow-net --allow-env --allow-read backend/scripts/prewarm-catalogue.ts
 *   deno run --allow-net --allow-env --allow-read backend/scripts/prewarm-catalogue.ts --submit
 *
 * Options: --languages=en,hi,ml  --mode=standard  --limit=N  --resume=<batch id>
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AnthropicBatchClient, type BatchRequest } from '../supabase/functions/_shared/services/llm-clients/anthropic-batch.ts'
import { createStandardPass1Prompt, createStandardPass2Prompt, combineStandardPasses } from '../supabase/functions/_shared/services/llm-utils/standard-multipass.ts'
import { calculateOptimalTokens } from '../supabase/functions/_shared/services/llm-utils/prompt-builder.ts'
import { getLanguageConfig } from '../supabase/functions/_shared/services/llm-config/language-configs.ts'
import type { LLMGenerationParams } from '../supabase/functions/_shared/services/llm-types.ts'

const MODEL = 'claude-sonnet-4-5-20250929'
// Batch pricing is half the standard rate, per million tokens.
const PRICE_PER_MTOK = { input: 1.5, output: 7.5 }
const POLL_SECONDS = 60

interface Lesson {
  topic_id: string
  title: string
  description: string | null
  path_title: string
  path_description: string | null
  disciple_level: string
}

function arg(name: string, fallback: string): string {
  const hit = Deno.args.find((a) => a.startsWith(`--${name}=`))
  return hit ? hit.slice(name.length + 3) : fallback
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name)
  if (!value) throw new Error(`${name} is not set`)
  return value
}

/** Catalogue lessons in [language] that have no cached guide for [mode] yet. */
// deno-lint-ignore no-explicit-any -- the generated database types are not wired up in scripts
async function lessonsNeedingGuides(
  db: any,
  language: string,
  mode: string,
  limit: number,
): Promise<Lesson[]> {
  const { data: rows, error } = await db.rpc('prewarm_missing_lessons', {
    p_language: language,
    p_study_mode: mode,
    p_limit: limit,
  })
  if (error) throw new Error(`Could not list lessons: ${error.message}`)
  return (rows ?? []) as Lesson[]
}

function paramsFor(lesson: Lesson, language: string, mode: string): LLMGenerationParams {
  return {
    inputType: 'topic',
    inputValue: lesson.title,
    topicDescription: lesson.description ?? undefined,
    pathTitle: lesson.path_title,
    pathDescription: lesson.path_description ?? undefined,
    discipleLevel: lesson.disciple_level,
    language,
    studyMode: mode as LLMGenerationParams['studyMode'],
  }
}

/** `topicId|language|pass` — the id Anthropic echoes back with each result. */
function customId(topicId: string, language: string, pass: 1 | 2): string {
  return `${topicId}|${language}|pass${pass}`
}

function parseCustomId(id: string): { topicId: string; language: string; pass: number } {
  const [topicId, language, pass] = id.split('|')
  return { topicId, language, pass: Number(pass.replace('pass', '')) }
}

function extractJson(text: string): Record<string, unknown> {
  const start = text.indexOf('{')
  const end = text.lastIndexOf('}')
  if (start === -1 || end === -1) throw new Error('No JSON object in response')
  return JSON.parse(text.slice(start, end + 1))
}

/** Waits for [batchId] to finish, reporting progress as it goes. */
async function awaitBatch(client: AnthropicBatchClient, batchId: string): Promise<void> {
  while (true) {
    const status = await client.status(batchId)
    const { succeeded, errored, processing } = status.counts
    console.log(`[prewarm] ${batchId}: ${succeeded} done, ${errored} failed, ${processing} in progress`)
    if (status.processingStatus === 'ended') return
    await new Promise((resolve) => setTimeout(resolve, POLL_SECONDS * 1000))
  }
}

async function main(): Promise<void> {
  const submit = Deno.args.includes('--submit')
  const languages = arg('languages', 'en,hi,ml').split(',').map((l) => l.trim()).filter(Boolean)
  const mode = arg('mode', 'standard')
  const limit = Number(arg('limit', '1000'))

  if (mode !== 'standard') {
    throw new Error(`Only standard mode is supported today; got "${mode}"`)
  }

  // deno-lint-ignore no-explicit-any -- see lessonsNeedingGuides
  const db: any = createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'))

  // Round 1: one pass-1 request per missing lesson, across every language.
  const pass1Requests: BatchRequest[] = []
  const lessonsById = new Map<string, { lesson: Lesson; language: string }>()

  for (const language of languages) {
    const config = getLanguageConfig(language)
    if (!config) throw new Error(`Unknown language "${language}"`)

    const lessons = await lessonsNeedingGuides(db, language, mode, limit)
    console.log(`[prewarm] ${language}: ${lessons.length} lessons without a ${mode} guide`)

    for (const lesson of lessons) {
      const params = paramsFor(lesson, language, mode)
      const prompt = createStandardPass1Prompt(params, config)
      pass1Requests.push({
        customId: customId(lesson.topic_id, language, 1),
        model: MODEL,
        maxTokens: calculateOptimalTokens(params, config),
        temperature: config.temperature,
        system: [
          { type: 'text', text: prompt.sharedSystem, cache_control: { type: 'ephemeral' } },
          { type: 'text', text: prompt.passSystem, cache_control: { type: 'ephemeral' } },
        ],
        userMessage: prompt.userMessage,
      })
      lessonsById.set(`${lesson.topic_id}|${language}`, { lesson, language })
    }
  }

  if (pass1Requests.length === 0) {
    console.log('[prewarm] Nothing to do: every lesson already has a guide.')
    return
  }

  // Rough estimate from the measured shape of a standard guide, doubled for the
  // two passes. Real cost is reported at the end from the batch's own counts.
  const estimatedGuides = pass1Requests.length
  const estimatedCost = estimatedGuides * 2 *
    ((6000 * PRICE_PER_MTOK.input + 3000 * PRICE_PER_MTOK.output) / 1_000_000)

  console.log(`[prewarm] ${estimatedGuides} guides, two passes each`)
  console.log(`[prewarm] estimated cost at batch pricing: $${estimatedCost.toFixed(2)}`)

  if (!submit) {
    console.log('[prewarm] Dry run. Nothing was sent and nothing was written. Pass --submit to run it.')
    return
  }

  const client = new AnthropicBatchClient(requireEnv('ANTHROPIC_API_KEY'))
  let inputTokens = 0
  let outputTokens = 0

  const batch1 = await client.submit(pass1Requests)
  await awaitBatch(client, batch1)

  const pass1Data = new Map<string, { summary: string; context: string; passage: string; interpretationPart1: string }>()
  const failures: string[] = []

  for await (const result of client.results(batch1)) {
    const { topicId, language } = parseCustomId(result.customId)
    if (result.error || !result.content) {
      failures.push(`${topicId} ${language} pass1: ${result.error ?? 'no content'}`)
      continue
    }
    inputTokens += result.inputTokens ?? 0
    outputTokens += result.outputTokens ?? 0
    try {
      pass1Data.set(`${topicId}|${language}`, extractJson(result.content) as never)
    } catch (error) {
      failures.push(`${topicId} ${language} pass1: ${(error as Error).message}`)
    }
  }

  // Round 2: pass 2 for every lesson whose pass 1 came back cleanly.
  const pass2Requests: BatchRequest[] = []
  for (const [key, pass1] of pass1Data) {
    const entry = lessonsById.get(key)
    if (!entry) continue
    const config = getLanguageConfig(entry.language)!
    const params = paramsFor(entry.lesson, entry.language, mode)
    const prompt = createStandardPass2Prompt(params, config, pass1)
    pass2Requests.push({
      customId: customId(entry.lesson.topic_id, entry.language, 2),
      model: MODEL,
      maxTokens: calculateOptimalTokens(params, config),
      temperature: config.temperature,
      system: [
        { type: 'text', text: prompt.sharedSystem, cache_control: { type: 'ephemeral' } },
        { type: 'text', text: prompt.passSystem, cache_control: { type: 'ephemeral' } },
      ],
      userMessage: prompt.userMessage,
    })
  }

  const batch2 = await client.submit(pass2Requests)
  await awaitBatch(client, batch2)

  let written = 0
  for await (const result of client.results(batch2)) {
    const { topicId, language } = parseCustomId(result.customId)
    const key = `${topicId}|${language}`
    const entry = lessonsById.get(key)
    const pass1 = pass1Data.get(key)
    if (result.error || !result.content || !entry || !pass1) {
      failures.push(`${topicId} ${language} pass2: ${result.error ?? 'no content'}`)
      continue
    }
    inputTokens += result.inputTokens ?? 0
    outputTokens += result.outputTokens ?? 0

    try {
      const pass2 = extractJson(result.content)
      const guide = combineStandardPasses(pass1, pass2 as never)

      const { error } = await db.from('study_guides').insert({
        input_type: 'topic',
        input_value: entry.lesson.title,
        input_value_hash: await hashInput('topic', language, mode, entry.lesson.title),
        language,
        study_mode: mode,
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
      if (error && error.code !== '23505') {
        failures.push(`${topicId} ${language} write: ${error.message}`)
      } else if (!error) {
        written += 1
      }
    } catch (error) {
      failures.push(`${topicId} ${language} pass2: ${(error as Error).message}`)
    }
  }

  const cost = (inputTokens * PRICE_PER_MTOK.input + outputTokens * PRICE_PER_MTOK.output) / 1_000_000
  console.log(`[prewarm] wrote ${written} guides`)
  console.log(`[prewarm] tokens: ${inputTokens} in, ${outputTokens} out — $${cost.toFixed(2)} at batch pricing`)

  if (failures.length > 0) {
    console.log(`[prewarm] ${failures.length} did not complete; the app will generate these on demand:`)
    for (const failure of failures) console.log(`  - ${failure}`)
  }
}

/** The same hash the repository writes, so a title lookup still finds these rows. */
async function hashInput(type: string, language: string, mode: string, value: string): Promise<string> {
  const normalized = value.toLowerCase().trim().replace(/\s+/g, ' ')
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(`${type}:${language}:${mode}:${normalized}`),
  )
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

if (import.meta.main) {
  main().catch((error) => {
    console.error('[prewarm] failed:', error.message)
    Deno.exit(1)
  })
}
