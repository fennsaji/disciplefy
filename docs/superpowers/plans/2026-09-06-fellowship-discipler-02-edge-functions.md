# Fellowship 1.0.5 — Plan 02: Edge Functions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the existing fellowship Edge Functions every Discipler capability: trigger classification, queueing, rule reactions, the internal reply route with model call and guide lookup, mentor oversight pushes, admin flags and mentor preferences, multiple mentors, review mode, and moderation rules.

**Architecture:** Pure helpers in `_shared/utils/discipler.ts` (unit-tested with no I/O), a prompt module, a DB/push service `_shared/services/discipler-service.ts`, one new `LLMService` method, and new `pathname.endsWith(...)` routes inside the existing functions. Every handler keeps the repo's auth idiom (`services.supabaseServiceClient.auth.getUser(token)` then service-role `db`). No new Edge Functions.

**Tech Stack:** Deno, TypeScript, Supabase JS v2, Anthropic client already in `_shared`, `deno test` with duck-typed fakes.

**Spec:** `docs/superpowers/specs/2026-09-06-fellowship-discipler-redesign-design.md` §1, §2, §4, §5, §8, §10. Index: `2026-09-06-fellowship-discipler-00-index.md`. Requires Plan 01 applied locally.

## Global Constraints

See index. Relevant here:
- `DISCIPLER_USER_ID = '00000000-0000-4000-8000-00000000d15c'`.
- Model `claude-haiku-4-5-20251001`, `maxTokens: 350`, `temperature: 0.3`.
- Internal routes accept `X-Internal-Api-Key` (validated through `services.authService.getUserContext(req)` returning `userId === '00000000-0000-0000-0000-000000000000'`) or the service-role bearer.
- Every FCM payload `type` added here must also be added to the Dart `validTypes` set (Task 11) or `push-type-routing-drift.test.ts` fails.
- Tests run per file: `deno test --allow-read --allow-env <file>`. Type check: `cd backend && sh scripts/check-quick.sh`.

---

### Task 1: Pure trigger helpers

**Files:**
- Create: `backend/supabase/functions/_shared/utils/discipler.ts`
- Test: `backend/supabase/functions/_shared/utils/discipler.test.ts`

**Interfaces:**
- Produces:
```ts
export const DISCIPLER_USER_ID = '00000000-0000-4000-8000-00000000d15c'
export const DISCIPLER_SYSTEM_USER_ID = '00000000-0000-0000-0000-000000000000'
export type DisciplerTrigger = 'mention' | 'question' | 'react'
export type DisciplerReaction = 'amen' | 'heart' | 'fire' | 'hands'
export interface FellowshipDisciplerSettings {
  discipler_allowed: boolean; discipler_reply_mode: 'off' | 'auto' | 'review';
  discipler_reply_scope: 'all' | 'lessons_only'; discipler_reply_delay_min: number;
  discipler_react_enabled: boolean
}
export interface ClassifyInput {
  content: string; postType: string; topicId: string | null; toMentors: boolean;
  authorIsMentor: boolean; authorUserId: string; settings: FellowshipDisciplerSettings; globalEnabled: boolean
}
export type Classification = { trigger: 'mention' | 'question'; delayMinutes: number } | { trigger: 'react'; reaction: DisciplerReaction } | null
export function mentionsDiscipler(content: string): boolean
export function isQuestionLike(content: string, postType: string): boolean
export function ruleReactionFor(postType: string, content: string): DisciplerReaction | null
export function classifyPost(input: ClassifyInput): Classification
export function classifyComment(input: { content: string; authorUserId: string; settings: FellowshipDisciplerSettings; globalEnabled: boolean }): { trigger: 'mention' } | null
export function runAfterFor(delayMinutes: number, now?: Date): string
```

- [ ] **Step 1: Write the failing tests**

```ts
// backend/supabase/functions/_shared/utils/discipler.test.ts
// Run with: deno test discipler.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  classifyComment, classifyPost, DISCIPLER_USER_ID, isQuestionLike,
  mentionsDiscipler, ruleReactionFor, runAfterFor,
} from './discipler.ts'

const settings = {
  discipler_allowed: true, discipler_reply_mode: 'auto' as const,
  discipler_reply_scope: 'all' as const, discipler_reply_delay_min: 30,
  discipler_react_enabled: true,
}
const base = {
  postType: 'general', topicId: null, toMentors: false, authorIsMentor: false,
  authorUserId: 'user-1', settings, globalEnabled: true,
}

Deno.test('mentionsDiscipler is case-insensitive and word-bounded', () => {
  assertEquals(mentionsDiscipler('Hey @Discipler can you help?'), true)
  assertEquals(mentionsDiscipler('hey @discipler'), true)
  assertEquals(mentionsDiscipler('email me at x@disciplerhub.com'), false)
  assertEquals(mentionsDiscipler('no mention here'), false)
})

Deno.test('isQuestionLike needs post_type question or a ? with 15+ chars', () => {
  assertEquals(isQuestionLike('why?', 'general'), false)
  assertEquals(isQuestionLike('Kya prayer ke liye fixed time hona chahiye?', 'general'), true)
  assertEquals(isQuestionLike('Is fasting required？', 'general'), true)
  assertEquals(isQuestionLike('short', 'question'), true)
  assertEquals(isQuestionLike('Is fasting required?', 'prayer'), false)
})

Deno.test('ruleReactionFor maps post types, never i_prayed', () => {
  assertEquals(ruleReactionFor('prayer', 'pray for me'), 'amen')
  assertEquals(ruleReactionFor('praise', 'God is good'), 'hands')
  assertEquals(ruleReactionFor('study_note', 'note'), 'heart')
  assertEquals(ruleReactionFor('shared_guide', 'guide'), 'heart')
  assertEquals(ruleReactionFor('general', 'we meet sunday'), 'heart')
  assertEquals(ruleReactionFor('general', 'is this ok? yes it is ok'), null)
  assertEquals(ruleReactionFor('daily', 'x'), null)
  assertEquals(ruleReactionFor('question', 'x'), null)
})

Deno.test('classifyPost: mention wins over everything, no delay', () => {
  const c = classifyPost({ ...base, content: '@Discipler is fasting required?', toMentors: true, authorIsMentor: true })
  assertEquals(c, { trigger: 'mention', delayMinutes: 0 })
})

Deno.test('classifyPost: question honours delay and scope', () => {
  assertEquals(classifyPost({ ...base, content: 'Is fasting required for believers?' }),
    { trigger: 'question', delayMinutes: 30 })
  assertEquals(classifyPost({ ...base, content: 'Is fasting required for believers?',
    settings: { ...settings, discipler_reply_scope: 'lessons_only' } }), null)
  assertEquals(classifyPost({ ...base, content: 'Is fasting required for believers?', topicId: 't1',
    settings: { ...settings, discipler_reply_scope: 'lessons_only' } }),
    { trigger: 'question', delayMinutes: 30 })
})

Deno.test('classifyPost: mentor questions, to_mentors, off mode, global off, system author → null or react', () => {
  assertEquals(classifyPost({ ...base, content: 'Is fasting required for believers?', authorIsMentor: true }), null)
  assertEquals(classifyPost({ ...base, content: 'Is fasting required for believers?', toMentors: true }), null)
  assertEquals(classifyPost({ ...base, content: 'Is fasting required for believers?',
    settings: { ...settings, discipler_reply_mode: 'off' } }), null)
  assertEquals(classifyPost({ ...base, content: '@Discipler hi', globalEnabled: false }), null)
  assertEquals(classifyPost({ ...base, content: 'pray for me', postType: 'prayer', authorUserId: DISCIPLER_USER_ID }), null)
})

Deno.test('classifyPost: reactions respect the mentor toggle and allowed flag', () => {
  assertEquals(classifyPost({ ...base, content: 'pray for me', postType: 'prayer' }), { trigger: 'react', reaction: 'amen' })
  assertEquals(classifyPost({ ...base, content: 'pray for me', postType: 'prayer',
    settings: { ...settings, discipler_react_enabled: false } }), null)
  assertEquals(classifyPost({ ...base, content: 'pray for me', postType: 'prayer',
    settings: { ...settings, discipler_allowed: false } }), null)
  assertEquals(classifyPost({ ...base, content: 'pray for me', postType: 'prayer',
    settings: { ...settings, discipler_reply_mode: 'off' } }), { trigger: 'react', reaction: 'amen' })
})

Deno.test('classifyComment only fires on mention', () => {
  assertEquals(classifyComment({ content: '@Discipler what about John 15?', authorUserId: 'u', settings, globalEnabled: true }), { trigger: 'mention' })
  assertEquals(classifyComment({ content: 'what about John 15?', authorUserId: 'u', settings, globalEnabled: true }), null)
  assertEquals(classifyComment({ content: '@Discipler x', authorUserId: DISCIPLER_USER_ID, settings, globalEnabled: true }), null)
})

Deno.test('runAfterFor adds minutes', () => {
  assertEquals(runAfterFor(30, new Date('2026-09-06T00:00:00Z')), '2026-09-06T00:30:00.000Z')
})
```

- [ ] **Step 2: Run to verify failure**

Run: `cd backend/supabase/functions/_shared/utils && deno test discipler.test.ts`
Expected: FAIL, module not found.

- [ ] **Step 3: Implement**

```ts
// backend/supabase/functions/_shared/utils/discipler.ts
/**
 * Pure Discipler trigger rules. No I/O so they are unit-testable.
 * Spec: docs/superpowers/specs/2026-09-06-fellowship-discipler-redesign-design.md §2
 */
export const DISCIPLER_USER_ID = '00000000-0000-4000-8000-00000000d15c'
export const DISCIPLER_SYSTEM_USER_ID = '00000000-0000-0000-0000-000000000000'

export type DisciplerTrigger = 'mention' | 'question' | 'react'
export type DisciplerReaction = 'amen' | 'heart' | 'fire' | 'hands'

export interface FellowshipDisciplerSettings {
  discipler_allowed: boolean
  discipler_reply_mode: 'off' | 'auto' | 'review'
  discipler_reply_scope: 'all' | 'lessons_only'
  discipler_reply_delay_min: number
  discipler_react_enabled: boolean
}

export interface ClassifyInput {
  content: string
  postType: string
  topicId: string | null
  toMentors: boolean
  authorIsMentor: boolean
  authorUserId: string
  settings: FellowshipDisciplerSettings
  globalEnabled: boolean
}

export type Classification =
  | { trigger: 'mention' | 'question'; delayMinutes: number }
  | { trigger: 'react'; reaction: DisciplerReaction }
  | null

const MENTION_RE = /(^|[^\w])@discipler(?![\w.-])/i
const QUESTION_MARK_RE = /[?？]/
const NEVER_ANSWERED = new Set(['prayer', 'praise', 'shared_guide', 'daily', 'study_note'])

export function mentionsDiscipler(content: string): boolean {
  return MENTION_RE.test(content)
}

export function isQuestionLike(content: string, postType: string): boolean {
  if (NEVER_ANSWERED.has(postType)) return false
  if (postType === 'question') return true
  return content.trim().length >= 15 && QUESTION_MARK_RE.test(content)
}

export function ruleReactionFor(postType: string, content: string): DisciplerReaction | null {
  switch (postType) {
    case 'prayer': return 'amen'
    case 'praise': return 'hands'
    case 'study_note':
    case 'shared_guide': return 'heart'
    case 'general': return QUESTION_MARK_RE.test(content) ? null : 'heart'
    default: return null
  }
}

function replyEnabled(s: FellowshipDisciplerSettings, globalEnabled: boolean): boolean {
  return globalEnabled && s.discipler_allowed && s.discipler_reply_mode !== 'off'
}

export function classifyPost(input: ClassifyInput): Classification {
  const { content, postType, topicId, toMentors, authorIsMentor, authorUserId, settings, globalEnabled } = input
  if (!globalEnabled || !settings.discipler_allowed) return null
  if (authorUserId === DISCIPLER_USER_ID || authorUserId === DISCIPLER_SYSTEM_USER_ID) return null
  if (postType === 'daily') return null

  if (mentionsDiscipler(content)) {
    return settings.discipler_reply_mode === 'off' ? null : { trigger: 'mention', delayMinutes: 0 }
  }

  if (replyEnabled(settings, globalEnabled) && !authorIsMentor && !toMentors && isQuestionLike(content, postType)) {
    if (settings.discipler_reply_scope === 'lessons_only' && !topicId) return null
    return { trigger: 'question', delayMinutes: settings.discipler_reply_delay_min }
  }

  if (settings.discipler_react_enabled && !isQuestionLike(content, postType)) {
    const reaction = ruleReactionFor(postType, content)
    if (reaction) return { trigger: 'react', reaction }
  }
  return null
}

export function classifyComment(input: {
  content: string; authorUserId: string; settings: FellowshipDisciplerSettings; globalEnabled: boolean
}): { trigger: 'mention' } | null {
  const { content, authorUserId, settings, globalEnabled } = input
  if (!replyEnabled(settings, globalEnabled)) return null
  if (authorUserId === DISCIPLER_USER_ID || authorUserId === DISCIPLER_SYSTEM_USER_ID) return null
  return mentionsDiscipler(content) ? { trigger: 'mention' } : null
}

export function runAfterFor(delayMinutes: number, now: Date = new Date()): string {
  return new Date(now.getTime() + delayMinutes * 60_000).toISOString()
}
```

- [ ] **Step 4: Run tests**

Run: `deno test discipler.test.ts` → PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/functions/_shared/utils/discipler.ts backend/supabase/functions/_shared/utils/discipler.test.ts
git commit -m "feat(discipler): pure trigger classification helpers"
```

---

### Task 2: Prompt builder and output parser

**Files:**
- Create: `backend/supabase/functions/_shared/prompts/discipler-prompt.ts`
- Test: `backend/supabase/functions/_shared/prompts/discipler-prompt.test.ts`

**Interfaces:**
- Consumes: `THEOLOGICAL_FOUNDATION` from `_shared/services/llm-utils/prompt-builder.ts`, `cleanJSONResponse` from `_shared/services/llm-utils/response-parser.ts`.
- Produces:
```ts
export interface DisciplerPromptInput {
  trigger: 'mention' | 'question'; fellowshipLanguage: 'en' | 'hi' | 'ml'
  question: string; askerName: string; guideContext: string | null
  thread: { author: string; isMentor: boolean; content: string }[]
}
export interface DisciplerOutput {
  action: 'reply' | 'react'; reaction: 'amen' | 'heart' | 'fire' | 'hands' | null
  language: 'en' | 'hi' | 'ml' | 'hinglish' | 'manglish'; reply: string | null
  guide_request: { input_type: 'topic' | 'scripture'; input_value: string } | null
}
export function buildDisciplerSystemPrompt(): string
export function buildDisciplerUserMessage(input: DisciplerPromptInput): string
export function parseDisciplerOutput(raw: string, trigger: 'mention' | 'question'): DisciplerOutput
export const MENTOR_CLOSER: Record<DisciplerOutput['language'], string>
```

- [ ] **Step 1: Write the failing tests**

```ts
// backend/supabase/functions/_shared/prompts/discipler-prompt.test.ts
// Run with: deno test discipler-prompt.test.ts
import { assertEquals, assertThrows } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildDisciplerSystemPrompt, buildDisciplerUserMessage, parseDisciplerOutput } from './discipler-prompt.ts'

Deno.test('system prompt carries the theological foundation and language rule', () => {
  const p = buildDisciplerSystemPrompt()
  assertEquals(p.includes('Sola'), true)
  assertEquals(p.includes('Hinglish'), true)
  assertEquals(p.includes('"action"'), true)
})

Deno.test('user message includes context, thread and asker', () => {
  const m = buildDisciplerUserMessage({
    trigger: 'question', fellowshipLanguage: 'hi', question: 'Kya fasting zaroori hai?',
    askerName: 'Rahul', guideContext: 'Fasting summary…',
    thread: [{ author: 'Anna', isMentor: true, content: 'Good question' }],
  })
  assertEquals(m.includes('Fellowship language: hi'), true)
  assertEquals(m.includes('Rahul'), true)
  assertEquals(m.includes('[mentor] Anna: Good question'), true)
  assertEquals(m.includes('Fasting summary…'), true)
})

Deno.test('parse accepts a fenced valid reply and normalises nulls', () => {
  const raw = '```json\n{"action":"reply","reaction":null,"language":"hinglish","reply":"Daniel 6:10","guide_request":null}\n```'
  assertEquals(parseDisciplerOutput(raw, 'question'), {
    action: 'reply', reaction: null, language: 'hinglish', reply: 'Daniel 6:10', guide_request: null,
  })
})

Deno.test('parse forces reply on mention and rejects bad shapes', () => {
  const react = '{"action":"react","reaction":"heart","language":"en","reply":null,"guide_request":null}'
  assertEquals(parseDisciplerOutput(react, 'question').action, 'react')
  assertThrows(() => parseDisciplerOutput(react, 'mention'))
  assertThrows(() => parseDisciplerOutput('{"action":"react","reaction":"i_prayed","language":"en","reply":null,"guide_request":null}', 'question'))
  assertThrows(() => parseDisciplerOutput('{"action":"reply","reaction":null,"language":"fr","reply":"x","guide_request":null}', 'question'))
  assertThrows(() => parseDisciplerOutput('{"action":"reply","reaction":null,"language":"en","reply":"","guide_request":null}', 'question'))
  assertThrows(() => parseDisciplerOutput('not json', 'question'))
})

Deno.test('parse validates guide_request', () => {
  const ok = '{"action":"reply","reaction":null,"language":"en","reply":"x","guide_request":{"input_type":"scripture","input_value":"John 15"}}'
  assertEquals(parseDisciplerOutput(ok, 'mention').guide_request, { input_type: 'scripture', input_value: 'John 15' })
  assertThrows(() => parseDisciplerOutput('{"action":"reply","reaction":null,"language":"en","reply":"x","guide_request":{"input_type":"video","input_value":"x"}}', 'mention'))
})
```

- [ ] **Step 2: Run to verify failure**

Run: `cd backend/supabase/functions/_shared/prompts && deno test discipler-prompt.test.ts` → FAIL, module not found.

- [ ] **Step 3: Implement**

```ts
// backend/supabase/functions/_shared/prompts/discipler-prompt.ts
import { THEOLOGICAL_FOUNDATION } from '../services/llm-utils/prompt-builder.ts'
import { cleanJSONResponse } from '../services/llm-utils/response-parser.ts'

export interface DisciplerPromptInput {
  trigger: 'mention' | 'question'
  fellowshipLanguage: 'en' | 'hi' | 'ml'
  question: string
  askerName: string
  guideContext: string | null
  thread: { author: string; isMentor: boolean; content: string }[]
}

export interface DisciplerOutput {
  action: 'reply' | 'react'
  reaction: 'amen' | 'heart' | 'fire' | 'hands' | null
  language: 'en' | 'hi' | 'ml' | 'hinglish' | 'manglish'
  reply: string | null
  guide_request: { input_type: 'topic' | 'scripture'; input_value: string } | null
}

export const MENTOR_CLOSER: Record<DisciplerOutput['language'], string> = {
  en: 'A mentor may add more.',
  hi: 'एक मेंटर और भी जोड़ सकते हैं।',
  ml: 'ഒരു മെന്റർ കൂടുതൽ കൂട്ടിച്ചേർക്കാം.',
  hinglish: 'Mentor aur add kar sakte hain.',
  manglish: 'Oru mentor koodi parayaam.',
}

const LANGUAGES = new Set(['en', 'hi', 'ml', 'hinglish', 'manglish'])
const REACTIONS = new Set(['amen', 'heart', 'fire', 'hands'])
const INPUT_TYPES = new Set(['topic', 'scripture'])

export function buildDisciplerSystemPrompt(): string {
  return `${THEOLOGICAL_FOUNDATION}

You are Discipler, an AI helper inside a Disciplefy fellowship group. You are not a human and never claim to be.

TASK: Read a member's post (and any thread) and return ONE JSON object:
{
  "action": "reply" | "react",
  "reaction": "amen" | "heart" | "fire" | "hands" | null,
  "language": "en" | "hi" | "ml" | "hinglish" | "manglish",
  "reply": string | null,
  "guide_request": { "input_type": "topic" | "scripture", "input_value": string } | null
}

RULES:
- Choose "react" (with a reaction, reply null) when the post is rhetorical, is a testimony phrased as a question, or a mentor has already answered it in the thread. Otherwise "reply".
- If the message explicitly mentions @Discipler you MUST reply.
- Reply language: default to the fellowship language. If the question is written in another script or in Hinglish/Manglish, mirror it: Devanagari → "hi"; Malayalam script → "ml"; Hindi in Latin letters → "hinglish"; Malayalam in Latin letters → "manglish". Write the reply in that language.
- Reply in at most 120 words, warm and pastoral, with one or two Scripture references using Arabic digits (e.g. Daniel 6:10). No headings, no lists.
- End the reply with the mentor closer for that language: en "A mentor may add more." · hi "एक मेंटर और भी जोड़ सकते हैं।" · ml "ഒരു മെന്റർ കൂടുതൽ കൂട്ടിച്ചേർക്കാം." · hinglish "Mentor aur add kar sakte hain." · manglish "Oru mentor koodi parayaam."
- If the question is not about faith, Scripture, or Christian life, reply with one sentence pointing the member to a mentor.
- Never give medical, legal, or financial direction.
- Set "guide_request" ONLY if the member explicitly asks for a study, guide, or lesson (e.g. "share a guide on grace", "guide for John 15"). input_type is "scripture" for a Bible reference, otherwise "topic". Never set it unprompted.
- Output only the JSON object.`
}

export function buildDisciplerUserMessage(input: DisciplerPromptInput): string {
  const thread = input.thread.length === 0
    ? '(no earlier comments)'
    : input.thread.map((c) => `${c.isMentor ? '[mentor] ' : ''}${c.author}: ${c.content}`).join('\n')
  const context = input.guideContext ? `RELATED STUDY GUIDE (for grounding only):\n${input.guideContext}` : 'RELATED STUDY GUIDE: none'
  return `Trigger: ${input.trigger}
Fellowship language: ${input.fellowshipLanguage}
Asked by: ${input.askerName}

MEMBER MESSAGE:
${input.question}

THREAD (oldest first):
${thread}

${context}`
}

export function parseDisciplerOutput(raw: string, trigger: 'mention' | 'question'): DisciplerOutput {
  let parsed: Record<string, unknown>
  try {
    parsed = JSON.parse(cleanJSONResponse(raw)) as Record<string, unknown>
  } catch {
    throw new Error('DISCIPLER_PARSE: not JSON')
  }
  const action = parsed.action
  if (action !== 'reply' && action !== 'react') throw new Error('DISCIPLER_PARSE: bad action')
  if (trigger === 'mention' && action !== 'reply') throw new Error('DISCIPLER_PARSE: mention must reply')
  const language = parsed.language
  if (typeof language !== 'string' || !LANGUAGES.has(language)) throw new Error('DISCIPLER_PARSE: bad language')

  const reaction = parsed.reaction ?? null
  if (reaction !== null && (typeof reaction !== 'string' || !REACTIONS.has(reaction))) throw new Error('DISCIPLER_PARSE: bad reaction')
  if (action === 'react' && reaction === null) throw new Error('DISCIPLER_PARSE: react needs reaction')

  const reply = parsed.reply ?? null
  if (action === 'reply' && (typeof reply !== 'string' || reply.trim().length === 0)) throw new Error('DISCIPLER_PARSE: reply empty')

  let guide_request: DisciplerOutput['guide_request'] = null
  const gr = parsed.guide_request
  if (gr !== null && gr !== undefined) {
    const g = gr as Record<string, unknown>
    if (typeof g.input_type !== 'string' || !INPUT_TYPES.has(g.input_type) ||
        typeof g.input_value !== 'string' || g.input_value.trim().length === 0) {
      throw new Error('DISCIPLER_PARSE: bad guide_request')
    }
    guide_request = { input_type: g.input_type as 'topic' | 'scripture', input_value: g.input_value.trim().slice(0, 120) }
  }

  return {
    action,
    reaction: (reaction as DisciplerOutput['reaction']) ?? null,
    language: language as DisciplerOutput['language'],
    reply: action === 'reply' ? (reply as string).trim().slice(0, 1000) : null,
    guide_request,
  }
}
```

- [ ] **Step 4: Run tests** → `deno test discipler-prompt.test.ts` PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/functions/_shared/prompts/discipler-prompt.ts backend/supabase/functions/_shared/prompts/discipler-prompt.test.ts
git commit -m "feat(discipler): prompt builder and strict output parser"
```

---

### Task 3: `LLMService.generateDisciplerReply`

**Files:**
- Modify: `backend/supabase/functions/_shared/services/llm-service.ts` (add method after `analyzeSentiment`, ~line 687)

**Interfaces:**
- Produces: `async generateDisciplerReply(prompt: { systemMessage: string; userMessage: string }): Promise<{ content: string; usage: LLMUsageMetadata; model: string; provider: 'anthropic' | 'openai' }>`

- [ ] **Step 1: Add the method**

```ts
  /**
   * Short JSON completion for Discipler fellowship replies.
   * Cheapest models on both providers; Anthropic preferred when available.
   */
  async generateDisciplerReply(prompt: { systemMessage: string; userMessage: string }): Promise<{
    content: string; usage: LLMUsageMetadata; model: string; provider: LLMProvider
  }> {
    const provider: LLMProvider = this.availableProviders.has('anthropic') ? 'anthropic' : this.getAnyAvailableProvider()
    if (provider === 'anthropic') {
      const model = 'claude-haiku-4-5-20251001'
      const result = await this.getAnthropicClient().call({
        systemMessage: prompt.systemMessage, userMessage: prompt.userMessage,
        temperature: 0.3, maxTokens: 350, model,
      })
      return { content: result.content, usage: result.usage, model, provider }
    }
    const model = 'gpt-4o-mini-2024-07-18'
    const result = await this.getOpenAIClient().call({
      systemMessage: prompt.systemMessage, userMessage: prompt.userMessage,
      temperature: 0.3, maxTokens: 350,
    })
    return { content: result.content, usage: result.usage, model, provider }
  }
```
If `getOpenAIClient().call` does not accept a `model` option, leave it off (as above); it defaults to `gpt-4o-mini-2024-07-18` for short tasks.

- [ ] **Step 2: Type check**

Run: `cd backend && sh scripts/check-quick.sh 2>&1 | tail -3` → `✅`.

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/functions/_shared/services/llm-service.ts
git commit -m "feat(llm): generateDisciplerReply on the lightweight models"
```

---

### Task 4: Discipler DB and push service

**Files:**
- Create: `backend/supabase/functions/_shared/services/discipler-service.ts`
- Test: `backend/supabase/functions/_shared/services/discipler-service.test.ts`

**Interfaces:**
- Consumes: `FCMService` (`_shared/fcm-service.ts`), `DISCIPLER_USER_ID`, types from Task 1.
- Produces:
```ts
export interface DisciplerFellowshipRow extends FellowshipDisciplerSettings { id: string; name: string; language: 'en'|'hi'|'ml'; daily_post_allowed: boolean; daily_post_on: boolean }
export async function loadFellowshipDiscipler(db: SupabaseClient, fellowshipId: string): Promise<DisciplerFellowshipRow | null>
export async function isDisciplerGloballyEnabled(db: SupabaseClient): Promise<boolean>
export async function enqueueReply(db, args: { postId: string; commentId?: string | null; fellowshipId: string; trigger: 'mention'|'question'; runAfter: string }): Promise<void>
export async function reactAsDiscipler(db, args: { postId: string; fellowshipId: string; reaction: DisciplerReaction; currentCounts: Record<string, number> }): Promise<Record<string, number>>
export async function recordActivity(db, args: { fellowshipId: string; kind: 'reply'|'react'|'draft'|'daily_post'; postId?: string|null; commentId?: string|null; reaction?: string|null; language?: string|null; summary: string; pushNow: boolean }): Promise<void>
export async function pushMentors(db, fellowshipId: string, notification: { title: string; body: string }, data: Record<string,string>, opts?: { excludeUserId?: string; respectMute?: boolean }): Promise<void>
export async function pushUsers(db, userIds: string[], notification: { title: string; body: string }, data: Record<string,string>): Promise<void>
```

- [ ] **Step 1: Write the failing test for `reactAsDiscipler` count math and `enqueueReply` idempotency using a fake db**

```ts
// backend/supabase/functions/_shared/services/discipler-service.test.ts
// Run with: deno test --allow-env discipler-service.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { enqueueReply, reactAsDiscipler } from './discipler-service.ts'

function fakeDb(log: string[]) {
  const chain = (table: string) => {
    const q: Record<string, unknown> = {}
    const self = () => q
    q.select = self; q.eq = self; q.maybeSingle = () => Promise.resolve({ data: null, error: null })
    q.insert = (row: unknown) => { log.push(`${table}:insert:${JSON.stringify(row)}`); return q }
    q.upsert = (row: unknown, o: unknown) => { log.push(`${table}:upsert:${JSON.stringify(row)}:${JSON.stringify(o)}`); return Promise.resolve({ error: null }) }
    q.update = (row: unknown) => { log.push(`${table}:update:${JSON.stringify(row)}`); return q }
    q.then = (res: (v: unknown) => void) => res({ data: null, error: null })
    return q
  }
  return { from: chain } as unknown as import('@supabase/supabase-js').SupabaseClient
}

Deno.test('reactAsDiscipler inserts a reaction and bumps the count', async () => {
  const log: string[] = []
  const counts = await reactAsDiscipler(fakeDb(log), {
    postId: 'p1', fellowshipId: 'f1', reaction: 'amen', currentCounts: { amen: 2 },
  })
  assertEquals(counts, { amen: 3 })
  assertEquals(log.some((l) => l.startsWith('fellowship_reactions:insert') && l.includes('00000000-0000-4000-8000-00000000d15c')), true)
  assertEquals(log.some((l) => l.startsWith('fellowship_posts:update') && l.includes('"amen":3')), true)
})

Deno.test('enqueueReply upserts on the (post, comment) target', async () => {
  const log: string[] = []
  await enqueueReply(fakeDb(log), { postId: 'p1', fellowshipId: 'f1', trigger: 'question', runAfter: '2026-09-06T00:30:00.000Z' })
  assertEquals(log.length, 1)
  assertEquals(log[0].includes('"trigger":"question"'), true)
  assertEquals(log[0].includes('ignoreDuplicates'), true)
})
```

- [ ] **Step 2: Run to verify failure** → module not found.

- [ ] **Step 3: Implement**

```ts
// backend/supabase/functions/_shared/services/discipler-service.ts
import type { SupabaseClient } from '@supabase/supabase-js'
import { FCMService } from '../fcm-service.ts'
import { DISCIPLER_USER_ID, type DisciplerReaction, type FellowshipDisciplerSettings } from '../utils/discipler.ts'

export interface DisciplerFellowshipRow extends FellowshipDisciplerSettings {
  id: string
  name: string
  language: 'en' | 'hi' | 'ml'
  daily_post_allowed: boolean
  daily_post_on: boolean
}

export const DISCIPLER_SETTINGS_COLUMNS =
  'id, name, language, discipler_allowed, discipler_reply_mode, discipler_reply_scope, discipler_reply_delay_min, discipler_react_enabled, daily_post_allowed, daily_post_on'

export async function loadFellowshipDiscipler(db: SupabaseClient, fellowshipId: string): Promise<DisciplerFellowshipRow | null> {
  const { data, error } = await db.from('fellowships').select(DISCIPLER_SETTINGS_COLUMNS).eq('id', fellowshipId).maybeSingle()
  if (error) { console.error('[discipler] settings load error:', error); return null }
  return (data as DisciplerFellowshipRow | null) ?? null
}

export async function isDisciplerGloballyEnabled(db: SupabaseClient): Promise<boolean> {
  const { data } = await db.from('system_config').select('value').eq('key', 'discipler_global_enabled').maybeSingle()
  return data?.value === 'true'
}

export async function enqueueReply(db: SupabaseClient, args: {
  postId: string; commentId?: string | null; fellowshipId: string; trigger: 'mention' | 'question'; runAfter: string
}): Promise<void> {
  const { error } = await db.from('discipler_reply_queue').upsert({
    post_id: args.postId,
    comment_id: args.commentId ?? null,
    fellowship_id: args.fellowshipId,
    trigger: args.trigger,
    run_after: args.runAfter,
    status: 'pending',
  }, { onConflict: 'post_id,comment_id', ignoreDuplicates: true })
  if (error) console.error('[discipler] enqueue error (non-fatal):', error)
}

export async function reactAsDiscipler(db: SupabaseClient, args: {
  postId: string; fellowshipId: string; reaction: DisciplerReaction; currentCounts: Record<string, number>
}): Promise<Record<string, number>> {
  const { error: insertError } = await db.from('fellowship_reactions').insert({
    post_id: args.postId, fellowship_id: args.fellowshipId, user_id: DISCIPLER_USER_ID, reaction_type: args.reaction,
  })
  if (insertError) { console.error('[discipler] reaction insert error:', insertError); return args.currentCounts }
  const counts = { ...args.currentCounts }
  counts[args.reaction] = (counts[args.reaction] || 0) + 1
  const { error: updateError } = await db.from('fellowship_posts').update({ reaction_counts: counts }).eq('id', args.postId)
  if (updateError) console.error('[discipler] reaction count update error (non-fatal):', updateError)
  return counts
}

export async function recordActivity(db: SupabaseClient, args: {
  fellowshipId: string; kind: 'reply' | 'react' | 'draft' | 'daily_post'
  postId?: string | null; commentId?: string | null; reaction?: string | null; language?: string | null
  summary: string; pushNow: boolean
}): Promise<void> {
  const { error } = await db.from('discipler_activity').insert({
    fellowship_id: args.fellowshipId, kind: args.kind, post_id: args.postId ?? null, comment_id: args.commentId ?? null,
    reaction: args.reaction ?? null, language: args.language ?? null, summary: args.summary.slice(0, 200),
    pushed_at: args.pushNow ? new Date().toISOString() : null,
  })
  if (error) console.error('[discipler] activity insert error (non-fatal):', error)
}

export async function pushUsers(db: SupabaseClient, userIds: string[], notification: { title: string; body: string }, data: Record<string, string>): Promise<void> {
  if (userIds.length === 0) return
  try {
    const { data: tokenRows } = await db.from('user_notification_tokens').select('fcm_token').in('user_id', userIds)
    const tokens = (tokenRows ?? []).map((r: { fcm_token: string }) => r.fcm_token).filter(Boolean)
    if (tokens.length === 0) return
    await new FCMService().sendBatchNotifications(tokens, notification, data)
  } catch (err) {
    console.error('[discipler] push error (non-fatal):', err)
  }
}

export async function pushMentors(db: SupabaseClient, fellowshipId: string, notification: { title: string; body: string }, data: Record<string, string>, opts: { excludeUserId?: string; respectMute?: boolean } = {}): Promise<void> {
  const { data: rows } = await db.rpc('fellowship_mentor_ids', { p_fellowship_id: fellowshipId })
  const ids = ((rows ?? []) as { user_id: string; discipler_activity_push: boolean }[])
    .filter((r) => !opts.respectMute || r.discipler_activity_push)
    .map((r) => r.user_id)
    .filter((id) => id !== opts.excludeUserId)
  await pushUsers(db, ids, notification, data)
}
```

- [ ] **Step 4: Run tests** → `deno test --allow-env discipler-service.test.ts` PASS. Type check with `sh scripts/check-quick.sh`.

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/functions/_shared/services/discipler-service.ts backend/supabase/functions/_shared/services/discipler-service.test.ts
git commit -m "feat(discipler): queue, reaction, activity and mentor push service"
```

---

### Task 5: Post creation triggers Discipler; comments enqueue on mention

**Files:**
- Modify: `backend/supabase/functions/fellowship-posts/index.ts` (`CreatePostRequest`, `handleCreatePost` ~187-379)
- Modify: `backend/supabase/functions/fellowship-comments/index.ts` (`handleCreateComment` ~133-234, GET select ~54-75)

**Interfaces:**
- Consumes: Task 1 `classifyPost`, `classifyComment`, `mentionsDiscipler`, `runAfterFor`; Task 4 service functions.
- Produces: posts accept `to_mentors: boolean`; `fellowship_posts.mentions_discipler`/`to_mentors` set; question posts push every mentor; comments set `mentions_discipler`.

- [ ] **Step 1: Extend the request type and insert in `handleCreatePost`**

Add `to_mentors?: boolean` to `CreatePostRequest`. In the insert object add:
```ts
      to_mentors: body.to_mentors === true,
      mentions_discipler: mentionsDiscipler(body.content),
```
with `import { classifyPost, mentionsDiscipler, runAfterFor } from '../_shared/utils/discipler.ts'` and `import { enqueueReply, isDisciplerGloballyEnabled, loadFellowshipDiscipler, pushMentors, reactAsDiscipler, recordActivity } from '../_shared/services/discipler-service.ts'`.

- [ ] **Step 2: Replace the mentor question push with an all-mentors push**

Replace the `mentorGetsQuestionPush` block (both the filter in the broadcast and the dedicated push) with:
```ts
  const questionToMentors = postType === 'question' || body.to_mentors === true
  const { data: mentorRows } = await db.rpc('fellowship_mentor_ids', { p_fellowship_id: body.fellowship_id })
  const mentorIds = new Set(((mentorRows ?? []) as { user_id: string }[]).map((r) => r.user_id))
  const authorIsMentor = mentorIds.has(user.id)
```
In the broadcast filter, replace `.filter((id: string) => !(mentorGetsQuestionPush && id === mentorUserId))` with `.filter((id: string) => !(questionToMentors && mentorIds.has(id)))`.
Replace the dedicated push with:
```ts
  if (questionToMentors) {
    const preview = post.content.length > 80 ? post.content.substring(0, 80) + '…' : post.content
    const title = body.to_mentors ? `🙋 ${authorDisplayName} asked the mentors` : `❓ ${authorDisplayName} asked a question`
    const p = pushMentors(db, body.fellowship_id, { title, body: preview },
      { type: 'fellowship_question', fellowship_id: body.fellowship_id, post_id: post.id }, { excludeUserId: user.id })
    if (typeof EdgeRuntime !== 'undefined') EdgeRuntime.waitUntil(p)
  }
```

- [ ] **Step 3: Add the Discipler hook after the pushes, before the response**

```ts
  // ── Discipler ────────────────────────────────────────────────────────
  const disciplerPromise = (async () => {
    try {
      const [settings, globalEnabled] = await Promise.all([
        loadFellowshipDiscipler(db, body.fellowship_id), isDisciplerGloballyEnabled(db),
      ])
      if (!settings) return
      const decision = classifyPost({
        content: post.content, postType, topicId: post.topic_id ?? null, toMentors: body.to_mentors === true,
        authorIsMentor, authorUserId: user.id, settings, globalEnabled,
      })
      if (!decision) return
      if (decision.trigger === 'react') {
        await reactAsDiscipler(db, { postId: post.id, fellowshipId: body.fellowship_id, reaction: decision.reaction, currentCounts: {} })
        await recordActivity(db, {
          fellowshipId: body.fellowship_id, kind: 'react', postId: post.id, reaction: decision.reaction,
          summary: `Reacted ${decision.reaction} to ${authorDisplayName}'s ${postType}`, pushNow: false,
        })
        return
      }
      await enqueueReply(db, {
        postId: post.id, fellowshipId: body.fellowship_id, trigger: decision.trigger,
        runAfter: runAfterFor(decision.delayMinutes),
      })
    } catch (err) {
      console.error('[fellowship-posts/create] Discipler hook error (non-fatal):', err)
    }
  })()
  if (typeof EdgeRuntime !== 'undefined') EdgeRuntime.waitUntil(disciplerPromise)
```
Also add `to_mentors: post.to_mentors ?? false, mentions_discipler: post.mentions_discipler ?? false` to the create response `data`, and add `to_mentors, mentions_discipler` to the GET list select string and the list mapping.

- [ ] **Step 4: Comments: mention detection and enqueue**

In `fellowship-comments/index.ts` `handleCreateComment`, add `mentions_discipler: mentionsDiscipler(trimmedContent)` to the insert, then after the FCM block:
```ts
  const disciplerPromise = (async () => {
    try {
      const [settings, globalEnabled] = await Promise.all([
        loadFellowshipDiscipler(db, post.fellowship_id), isDisciplerGloballyEnabled(db),
      ])
      if (!settings) return
      const decision = classifyComment({ content: trimmedContent, authorUserId: user.id, settings, globalEnabled })
      if (!decision) return
      await enqueueReply(db, { postId: body.post_id, commentId: comment.id, fellowshipId: post.fellowship_id, trigger: 'mention', runAfter: new Date().toISOString() })
    } catch (err) {
      console.error('[fellowship-comments/create] Discipler hook error (non-fatal):', err)
    }
  })()
  if (typeof EdgeRuntime !== 'undefined') EdgeRuntime.waitUntil(disciplerPromise)
```
Imports: `classifyComment, mentionsDiscipler` from `../_shared/utils/discipler.ts`; `enqueueReply, isDisciplerGloballyEnabled, loadFellowshipDiscipler` from `../_shared/services/discipler-service.ts`.

- [ ] **Step 5: Local smoke test**

Type check: `cd backend && sh scripts/check-quick.sh`. Then with functions serving, as Rahul (get a JWT via `curl -s -X POST http://127.0.0.1:54321/auth/v1/token?grant_type=password -H "apikey: <ANON>" -H "Content-Type: application/json" -d '{"email":"rahul@test.local","password":"Test1234!"}' | jq -r .access_token`):
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "update fellowships set discipler_allowed=true, is_official=true where id='f0000000-0000-0000-0000-000000000001'; update system_config set value='true' where key='discipler_global_enabled';"
curl -s -X POST http://127.0.0.1:54321/functions/v1/fellowship-posts -H "Authorization: Bearer $JWT" -H "apikey: $ANON" -H "Content-Type: application/json" -d '{"fellowship_id":"f0000000-0000-0000-0000-000000000001","content":"@Discipler is fasting required for every believer?","post_type":"question"}' | jq .data.mentions_discipler
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "select trigger,status from discipler_reply_queue order by created_at desc limit 1;"
```
Expected: `true`, then `mention|pending`. Post a prayer as Rahul and confirm `fellowship_reactions` has an `amen` row by `00000000-0000-4000-8000-00000000d15c` and `discipler_activity` has a `react` row.

- [ ] **Step 6: Commit**

```bash
git add backend/supabase/functions/fellowship-posts/index.ts backend/supabase/functions/fellowship-comments/index.ts
git commit -m "feat(discipler): classify posts and comments, enqueue replies, rule reactions, push all mentors"
```

---

### Task 6: `fellowship-posts/discipler-reply` and `fellowship-posts/notify` routes

**Files:**
- Create: `backend/supabase/functions/fellowship-posts/discipler-reply.ts`
- Create: `backend/supabase/functions/fellowship-posts/notify.ts`
- Modify: `backend/supabase/functions/fellowship-posts/index.ts` router (~635-656)
- Test: `backend/supabase/functions/fellowship-posts/discipler-reply.test.ts`

**Interfaces:**
- Consumes: Tasks 1–4; `validateInputSecurity`, `determineAction` from `_shared/services/llm-utils/security-validator.ts`; `services.llmService.generateDisciplerReply`; `services.costTrackingService.calculateCost`; `services.studyGuideRepository`-style hashing is NOT used — guide lookup is by normalized input through the same hash as `generateInputHash` (reproduce via `services.securityValidator.hashSensitiveData`).
- Produces:
  - `POST /fellowship-posts/discipler-reply` body `{ queue_id: string }` → `{ success: true, data: { status: 'done' | 'skipped_*', action?, comment_id? } }`.
  - `POST /fellowship-posts/notify` body `{ kind: 'daily_post', post_id }` or `{ kind: 'activity_digest', fellowship_id }` → `{ success: true, data: { sent: number } }`.
  - Exported pure helper `buildGuideAttachment(found: { id: string; title: string } | null, req: { input_type; input_value }, language: string)`.

- [ ] **Step 1: Write the failing test for the internal-auth guard and guide attachment helper**

```ts
// backend/supabase/functions/fellowship-posts/discipler-reply.test.ts
// Run with: deno test --allow-env discipler-reply.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildGuideAttachment, isInternalCaller } from './discipler-reply.ts'

Deno.test('buildGuideAttachment links a cached guide by id or falls back to inputs', () => {
  assertEquals(buildGuideAttachment({ id: 'g1', title: 'Prayer' }, { input_type: 'topic', input_value: 'prayer' }, 'hi'),
    { study_guide_id: 'g1', guide_title: 'Prayer', guide_input_type: 'topic', guide_input_value: 'prayer', guide_language: 'hi' })
  assertEquals(buildGuideAttachment(null, { input_type: 'scripture', input_value: 'John 15' }, 'en'),
    { study_guide_id: null, guide_title: 'John 15', guide_input_type: 'scripture', guide_input_value: 'John 15', guide_language: 'en' })
})

Deno.test('isInternalCaller accepts the nil system user or the service role bearer', () => {
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'srk')
  assertEquals(isInternalCaller({ userId: '00000000-0000-0000-0000-000000000000' }, 'Bearer nope'), true)
  assertEquals(isInternalCaller({ userId: 'someone' }, 'Bearer srk'), true)
  assertEquals(isInternalCaller({ userId: 'someone' }, 'Bearer nope'), false)
  assertEquals(isInternalCaller(null, 'Bearer srk'), true)
  assertEquals(isInternalCaller(null, null), false)
})
```

- [ ] **Step 2: Run to verify failure** → module not found.

- [ ] **Step 3: Implement `discipler-reply.ts`**

```ts
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
  await db.from('discipler_reply_queue').update({ status, last_error: lastError ?? null, updated_at: new Date().toISOString() }).eq('id', queueId)
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
    db.from('fellowship_posts').select('id, fellowship_id, author_user_id, content, post_type, topic_id, topic_title, to_mentors, reaction_counts, is_deleted').eq('id', q.post_id).maybeSingle(),
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
  const { data: mentorRows } = await db.rpc('fellowship_mentor_ids', { p_fellowship_id: q.fellowship_id })
  const mentorIds = new Set(((mentorRows ?? []) as { user_id: string }[]).map((r) => r.user_id))
  const decision = q.comment_id
    ? classifyComment({ content: question, authorUserId: askerId, settings, globalEnabled })
    : classifyPost({ content: question, postType: post.post_type, topicId: post.topic_id ?? null, toMentors: post.to_mentors === true,
        authorIsMentor: mentorIds.has(askerId), authorUserId: askerId, settings, globalEnabled })
  if (!decision || decision.trigger === 'react') return done('skipped_gate')
  const trigger = decision.trigger

  // Injection
  const sec = validateInputSecurity(question)
  if (!sec.isValid && determineAction(sec.riskScore) === 'blocked') return done('skipped_injection')

  // Budget
  const { data: budget } = await db.rpc('discipler_daily_budget', { p_fellowship_id: q.fellowship_id, p_user_id: askerId })
  const b = (budget as { user_count: number; fellowship_count: number }[] | null)?.[0]
  if (b && (b.user_count >= USER_DAILY_LIMIT || b.fellowship_count >= FELLOWSHIP_DAILY_LIMIT)) return done('skipped_budget')

  // Thread + context
  const { data: threadRows } = await db.from('fellowship_comments').select('author_user_id, content, created_at')
    .eq('post_id', post.id).eq('is_deleted', false).eq('is_pending_review', false).order('created_at', { ascending: false }).limit(5)
  const thread = await Promise.all(((threadRows ?? []) as { author_user_id: string; content: string }[]).reverse().map(async (c) => ({
    author: c.author_user_id === DISCIPLER_USER_ID ? 'Discipler' : await displayName(db, c.author_user_id),
    isMentor: mentorIds.has(c.author_user_id), content: c.content.slice(0, 400),
  })))
  const contextQuery = post.topic_title ?? question
  const { data: guideRows } = await db.rpc('discipler_related_guide', { p_query: contextQuery.slice(0, 200), p_language: settings.language })
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
  if (insertError || !comment) return done('failed', {}, insertError?.message ?? 'comment insert failed')

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
```

- [ ] **Step 4: Implement `notify.ts`**

```ts
// backend/supabase/functions/fellowship-posts/notify.ts
/**
 * POST /fellowship-posts/notify  (service-role bearer only; called by rs-backend)
 *   { kind: 'daily_post', post_id }             → push members about a Discipler daily post, push mentors
 *   { kind: 'activity_digest', fellowship_id }  → one push to mentors for unpushed react/daily rows
 */
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { pushMentors, pushUsers, recordActivity } from '../_shared/services/discipler-service.ts'
import { DISCIPLER_USER_ID } from '../_shared/utils/discipler.ts'

export async function handleNotify(req: Request, services: ServiceContainer): Promise<Response> {
  const srk = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!srk || req.headers.get('Authorization') !== `Bearer ${srk}`) throw new AppError('PERMISSION_DENIED', 'Service role required', 403)
  let body: { kind: string; post_id?: string; fellowship_id?: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  const db = services.supabaseServiceClient

  if (body.kind === 'daily_post') {
    if (!body.post_id) throw new AppError('VALIDATION_ERROR', 'post_id is required', 400)
    const { data: post } = await db.from('fellowship_posts').select('id, fellowship_id, content, topic_title').eq('id', body.post_id).maybeSingle()
    if (!post) throw new AppError('NOT_FOUND', 'Post not found', 404)
    const { data: f } = await db.from('fellowships').select('name').eq('id', post.fellowship_id).maybeSingle()
    const { data: members } = await db.from('fellowship_members').select('user_id').eq('fellowship_id', post.fellowship_id).eq('is_active', true)
    const ids = ((members ?? []) as { user_id: string }[]).map((m) => m.user_id).filter((id) => id !== DISCIPLER_USER_ID)
    const title = `📖 Today's study in ${f?.name ?? 'your fellowship'}`
    const bodyText = post.topic_title ?? post.content.slice(0, 80)
    await pushUsers(db, ids, { title, body: bodyText }, { type: 'fellowship_daily_post', fellowship_id: post.fellowship_id, post_id: post.id })
    await recordActivity(db, { fellowshipId: post.fellowship_id, kind: 'daily_post', postId: post.id, summary: `Posted today's study: ${bodyText}`, pushNow: false })
    return ok({ sent: ids.length })
  }

  if (body.kind === 'activity_digest') {
    if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
    const { data: rows } = await db.from('discipler_activity').select('id, kind').eq('fellowship_id', body.fellowship_id).is('pushed_at', null)
    const list = (rows ?? []) as { id: string; kind: string }[]
    if (list.length === 0) return ok({ sent: 0 })
    const reacts = list.filter((r) => r.kind === 'react').length
    const daily = list.filter((r) => r.kind === 'daily_post').length
    const parts = [reacts ? `${reacts} reaction${reacts === 1 ? '' : 's'}` : '', daily ? `${daily} daily post${daily === 1 ? '' : 's'}` : ''].filter(Boolean)
    const { data: f } = await db.from('fellowships').select('name').eq('id', body.fellowship_id).maybeSingle()
    await pushMentors(db, body.fellowship_id,
      { title: `✨ Discipler activity in ${f?.name ?? 'your fellowship'}`, body: parts.join(' · ') },
      { type: 'fellowship_discipler_activity', fellowship_id: body.fellowship_id }, { respectMute: true })
    await db.from('discipler_activity').update({ pushed_at: new Date().toISOString() }).in('id', list.map((r) => r.id))
    return ok({ sent: list.length })
  }

  throw new AppError('VALIDATION_ERROR', "kind must be 'daily_post' or 'activity_digest'", 400)
}

function ok(data: Record<string, unknown>): Response {
  return new Response(JSON.stringify({ success: true, data }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}
```

- [ ] **Step 5: Wire the router**

In `fellowship-posts/index.ts` `handlePosts`, inside the POST branch before the create fallback:
```ts
    if (pathname.endsWith('/discipler-reply')) return handleDisciplerReply(req, services)
    if (pathname.endsWith('/notify')) return handleNotify(req, services)
```
with imports `import { handleDisciplerReply } from './discipler-reply.ts'` and `import { handleNotify } from './notify.ts'`. Move `await checkMaintenanceMode(req, services)` below these two routes so background jobs still run during maintenance.

- [ ] **Step 6: Run tests and an end-to-end local call**

`deno test --allow-env discipler-reply.test.ts` → PASS. Type check. Then (requires `ANTHROPIC_API_KEY` in `backend/.env.local`):
```bash
QID=$(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "select id from discipler_reply_queue where status='pending' order by created_at desc limit 1")
curl -s -X POST http://127.0.0.1:54321/functions/v1/fellowship-posts/discipler-reply -H "X-Internal-Api-Key: $INTERNAL_API_KEY" -H "apikey: $ANON" -H "Content-Type: application/json" -d "{\"queue_id\":\"$QID\"}"
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -Atc "select action, language_detected, cost_usd from discipler_replies order by created_at desc limit 1; select content from fellowship_comments where author_user_id='00000000-0000-4000-8000-00000000d15c' order by created_at desc limit 1;"
```
Expected: `{"success":true,"data":{"status":"done","action":"reply",...}}`, a `reply|hinglish|0.00…` row, and a Hinglish comment ending with "Mentor aur add kar sakte hain."

- [ ] **Step 7: Commit**

```bash
git add backend/supabase/functions/fellowship-posts/
git commit -m "feat(discipler): internal reply route with model call, guide lookup, and notify route"
```

---

### Task 7: `fellowship` function: flags, preferences, mentors list, discover, join, activity list

**Files:**
- Modify: `backend/supabase/functions/fellowship/index.ts` (create ~519-586, update ~874-977, list ~41-148, discover ~331-473, join ~690-746, router ~983-1014)
- Modify: `backend/supabase/functions/fellowship-invites/index.ts:~265` (no change to push; confirm no system post is created — it already does not)

**Interfaces:**
- Produces:
  - Create body accepts `is_official, discipler_allowed, daily_post_allowed` (admin only; the latter two require `is_official`).
  - PATCH accepts admin flags (admin only) and mentor prefs `discipler_reply_mode, discipler_reply_scope, discipler_reply_delay_min, discipler_react_enabled, daily_post_on` (mentor), plus `posting_permission` (existing).
  - List response adds `mentors: [{ user_id, display_name, avatar_url }]`, `is_official`, `discipler_allowed`, `daily_post_allowed`, and the five prefs.
  - Discover response adds `is_official`, `discipler_allowed`; `max_members` may be `null`.
  - `GET /fellowship/discipler-activity?fellowship_id=&kind=&limit=&cursor=` (mentor) → `{ success, data: activity[] , pagination }`.
  - `PATCH` mentors may also set `discipler_activity_push` for their own member row.

- [ ] **Step 1: Create handler flags**

Extend the create body type with `is_official?: boolean; discipler_allowed?: boolean; daily_post_allowed?: boolean`. After the `max_members === null` admin check add:
```ts
  const wantsOfficial = body.is_official === true
  const wantsDiscipler = body.discipler_allowed === true
  const wantsDaily = body.daily_post_allowed === true
  if ((wantsOfficial || wantsDiscipler || wantsDaily) && !isAdmin) {
    throw new AppError('PERMISSION_DENIED', 'Only admins can set official or Discipler flags', 403)
  }
  if ((wantsDiscipler || wantsDaily) && !wantsOfficial) {
    throw new AppError('VALIDATION_ERROR', 'Discipler and daily post require an official fellowship', 400)
  }
```
and in the insert: `is_official: wantsOfficial, discipler_allowed: wantsDiscipler, daily_post_allowed: wantsDaily,`.

- [ ] **Step 2: Update handler**

Extend the body type:
```ts
  let body: {
    fellowship_id: string; name?: string; description?: string; max_members?: number | null; posting_permission?: string
    is_official?: boolean; discipler_allowed?: boolean; daily_post_allowed?: boolean
    discipler_reply_mode?: string; discipler_reply_scope?: string; discipler_reply_delay_min?: number
    discipler_react_enabled?: boolean; daily_post_on?: boolean; discipler_activity_push?: boolean
  }
```
After the `posting_permission` block add:
```ts
  const adminFlagKeys = ['is_official', 'discipler_allowed', 'daily_post_allowed'] as const
  if (adminFlagKeys.some((k) => body[k] !== undefined)) {
    const { data: profile } = await db.from('user_profiles').select('is_admin').eq('id', user.id).single()
    if (profile?.is_admin !== true) throw new AppError('PERMISSION_DENIED', 'Only admins can change official or Discipler flags', 403)
    for (const k of adminFlagKeys) if (typeof body[k] === 'boolean') updates[k] = body[k]
  }
  if (body.discipler_reply_mode !== undefined) {
    if (!['off', 'auto', 'review'].includes(body.discipler_reply_mode)) throw new AppError('VALIDATION_ERROR', "discipler_reply_mode must be 'off', 'auto' or 'review'", 400)
    updates.discipler_reply_mode = body.discipler_reply_mode
  }
  if (body.discipler_reply_scope !== undefined) {
    if (!['all', 'lessons_only'].includes(body.discipler_reply_scope)) throw new AppError('VALIDATION_ERROR', "discipler_reply_scope must be 'all' or 'lessons_only'", 400)
    updates.discipler_reply_scope = body.discipler_reply_scope
  }
  if (body.discipler_reply_delay_min !== undefined) {
    if (![0, 30, 120, 720].includes(body.discipler_reply_delay_min)) throw new AppError('VALIDATION_ERROR', 'discipler_reply_delay_min must be 0, 30, 120 or 720', 400)
    updates.discipler_reply_delay_min = body.discipler_reply_delay_min
  }
  if (typeof body.discipler_react_enabled === 'boolean') updates.discipler_react_enabled = body.discipler_react_enabled
  if (typeof body.daily_post_on === 'boolean') updates.daily_post_on = body.daily_post_on
  if (typeof body.discipler_activity_push === 'boolean') {
    await db.from('fellowship_members').update({ discipler_activity_push: body.discipler_activity_push })
      .eq('fellowship_id', body.fellowship_id).eq('user_id', user.id)
  }
```
Change `hasUpdate` to also accept the case where only `discipler_activity_push` was sent:
```ts
  const hasUpdate = Object.keys(updates).some(k => k !== 'updated_at') || typeof body.discipler_activity_push === 'boolean'
  if (!hasUpdate) throw new AppError('VALIDATION_ERROR', 'No valid fields provided to update', 400)
  if (Object.keys(updates).length === 1) return ok(fellowshipSettingsPayload(await reload()))
```
where the response `data` is extended with every flag/pref column (select `*` after update and map).

- [ ] **Step 3: List and discover**

In `handleListFellowships` select add `is_official, discipler_allowed, daily_post_allowed, discipler_reply_mode, discipler_reply_scope, discipler_reply_delay_min, discipler_react_enabled, daily_post_on` inside the `fellowships (...)` block. Replace the single-mentor lookup with a mentors list: query `fellowship_members` where `fellowship_id in (ids) and role='mentor' and is_active`, resolve names with the existing `auth.admin.getUserById` loop, and map:
```ts
        mentors: (mentorsByFellowship.get(fellowship.id) ?? []).map((m) => ({ user_id: m.userId, display_name: m.name, avatar_url: m.avatar })),
        mentor_name: (mentorsByFellowship.get(fellowship.id) ?? [])[0]?.name ?? null, // kept for older clients
        is_official: fellowship.is_official ?? false,
        discipler_allowed: fellowship.discipler_allowed ?? false,
        daily_post_allowed: fellowship.daily_post_allowed ?? false,
        discipler_reply_mode: fellowship.discipler_reply_mode ?? 'auto',
        discipler_reply_scope: fellowship.discipler_reply_scope ?? 'all',
        discipler_reply_delay_min: fellowship.discipler_reply_delay_min ?? 0,
        discipler_react_enabled: fellowship.discipler_react_enabled ?? true,
        daily_post_on: fellowship.daily_post_on ?? true,
```
Also expose the caller's own `discipler_activity_push` from their membership row as `my_discipler_activity_push`.
In `handleDiscoverFellowships` select add `is_official, discipler_allowed` and map them; `max_members` passes through as-is (may be null).

- [ ] **Step 4: Join: remove the system post**

Delete the `db.from('fellowship_posts').insert({ ... post_type: 'system' })` block (~700-706) and its `postError` warning. Keep the mentor push and change it to push every mentor:
```ts
  const joinPush = pushMentors(db, fellowship.id,
    { title: `👋 ${displayName} joined the fellowship`, body: `${displayName} joined ${fellowship.name}` },
    { type: 'fellowship_member_joined', fellowship_id: fellowship.id, user_id: user.id }, { excludeUserId: user.id })
  if (typeof EdgeRuntime !== 'undefined') EdgeRuntime.waitUntil(joinPush)
```
Apply the same `pushMentors` call in `fellowship-invites/index.ts` at the token-join push (~265).

- [ ] **Step 5: Activity list route**

Add before `const fellowshipId = ...` in the GET branch: `if (pathname.endsWith('/discipler-activity')) return handleDisciplerActivity(req, services)`.
```ts
async function handleDisciplerActivity(req: Request, services: ServiceContainer): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(authHeader.replace('Bearer ', ''))
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)
  const url = new URL(req.url)
  const fellowshipId = url.searchParams.get('fellowship_id')
  if (!fellowshipId || !UUID_RE.test(fellowshipId)) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  const kind = url.searchParams.get('kind')
  const cursor = url.searchParams.get('cursor')
  const limit = Math.min(Math.max(parseInt(url.searchParams.get('limit') || '30', 10) || 30, 1), 100)
  const db = services.supabaseServiceClient
  const { data: isMentor } = await db.rpc('is_fellowship_mentor', { p_fellowship_id: fellowshipId, p_user_id: user.id })
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  let q = db.from('discipler_activity')
    .select('id, kind, post_id, comment_id, reaction, language, summary, reviewed_by, reviewed_at, created_at, fellowship_posts(content, author_user_id, post_type, topic_title), fellowship_comments(content, is_pending_review, is_deleted)')
    .eq('fellowship_id', fellowshipId).order('created_at', { ascending: false }).limit(limit + 1)
  if (kind && ['reply', 'react', 'draft', 'daily_post'].includes(kind)) q = q.eq('kind', kind)
  if (cursor) q = q.lt('created_at', cursor)
  const { data, error } = await q
  if (error) { console.error('[fellowship/discipler-activity] query error:', error); throw new AppError('DATABASE_ERROR', 'Failed to load activity', 500) }
  const rows = data ?? []
  const hasMore = rows.length > limit
  const page = hasMore ? rows.slice(0, limit) : rows
  return new Response(JSON.stringify({
    success: true,
    data: page.map((r: any) => ({
      id: r.id, kind: r.kind, post_id: r.post_id, comment_id: r.comment_id, reaction: r.reaction, language: r.language,
      summary: r.summary, reviewed_at: r.reviewed_at, created_at: r.created_at,
      post: r.fellowship_posts ? { content: r.fellowship_posts.content, post_type: r.fellowship_posts.post_type, topic_title: r.fellowship_posts.topic_title } : null,
      comment: r.fellowship_comments ? { content: r.fellowship_comments.content, is_pending_review: r.fellowship_comments.is_pending_review, is_deleted: r.fellowship_comments.is_deleted } : null,
    })),
    pagination: { has_more: hasMore, next_cursor: hasMore ? page[page.length - 1].created_at : null },
  }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}
```

- [ ] **Step 6: Verify**

Type check. As Anna (admin+mentor): PATCH `{ fellowship_id, discipler_reply_mode: 'review', discipler_reply_delay_min: 30 }` → 200 with the prefs echoed; as Rahul the same PATCH → 403. GET `/fellowship` as Anna → `mentors` array length 1, `is_official: true`. GET `/fellowship/discipler-activity?fellowship_id=…` → the react/reply rows from Task 5/6.

- [ ] **Step 7: Commit**

```bash
git add backend/supabase/functions/fellowship/index.ts backend/supabase/functions/fellowship-invites/index.ts
git commit -m "feat(fellowship): admin flags, mentor Discipler prefs, mentors list, activity route, drop join posts"
```

---

### Task 8: Comments: review visibility, guide fields, approve/discard; admin delete; report guard

**Files:**
- Modify: `backend/supabase/functions/fellowship-comments/index.ts` (GET ~54-118, DELETE ~276-310, router ~322-336)
- Modify: `backend/supabase/functions/fellowship-posts/index.ts` (DELETE ~393-443, report ~568-629)

**Interfaces:**
- Produces: comment JSON gains `author_is_system, is_pending_review, mentions_discipler, study_guide_id, guide_title, guide_input_type, guide_input_value, guide_language`; `POST /fellowship-comments/approve { comment_id }`, `POST /fellowship-comments/discard { comment_id }` (mentor); admins may delete any post/comment; reporting a system author returns 400.

- [ ] **Step 1: GET filtering and fields**

Change the comments select to
`'id, post_id, content, author_user_id, is_deleted, created_at, is_pending_review, mentions_discipler, study_guide_id, guide_title, guide_input_type, guide_input_value, guide_language'`.
After the membership check compute `const { data: viewerIsMentor } = await db.rpc('is_fellowship_mentor', { p_fellowship_id: post.fellowship_id, p_user_id: user.id })` and add `if (!viewerIsMentor) commentsQuery = commentsQuery.eq('is_pending_review', false)`.
In the enrichment map add `author_is_system: c.author_user_id === DISCIPLER_USER_ID` and pass through the new columns.

- [ ] **Step 2: Approve and discard handlers**

```ts
async function handleReviewComment(req: Request, services: ServiceContainer, decision: 'approve' | 'discard'): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(authHeader.replace('Bearer ', ''))
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)
  let body: { comment_id: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.comment_id) throw new AppError('VALIDATION_ERROR', 'comment_id is required', 400)
  const db = services.supabaseServiceClient
  const { data: comment } = await db.from('fellowship_comments').select('id, post_id, fellowship_id, content, is_pending_review, author_user_id').eq('id', body.comment_id).eq('is_deleted', false).maybeSingle()
  if (!comment) throw new AppError('NOT_FOUND', 'Comment not found', 404)
  if (!comment.is_pending_review || comment.author_user_id !== DISCIPLER_USER_ID) throw new AppError('VALIDATION_ERROR', 'Comment is not a Discipler draft', 400)
  const { data: isMentor } = await db.rpc('is_fellowship_mentor', { p_fellowship_id: comment.fellowship_id, p_user_id: user.id })
  if (!isMentor) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)

  const now = new Date().toISOString()
  if (decision === 'approve') {
    await db.from('fellowship_comments').update({ is_pending_review: false }).eq('id', comment.id)
    const { data: post } = await db.from('fellowship_posts').select('author_user_id').eq('id', comment.post_id).maybeSingle()
    if (post?.author_user_id) {
      const p = pushUsers(db, [post.author_user_id], { title: '✨ Discipler replied to your question', body: comment.content.slice(0, 80) },
        { type: 'fellowship_discipler_reply', fellowship_id: comment.fellowship_id, post_id: comment.post_id, comment_id: comment.id })
      if (typeof EdgeRuntime !== 'undefined') EdgeRuntime.waitUntil(p)
    }
  } else {
    await db.from('fellowship_comments').update({ is_deleted: true }).eq('id', comment.id)
  }
  await db.from('discipler_activity').update({ reviewed_by: user.id, reviewed_at: now, kind: decision === 'approve' ? 'reply' : 'draft' }).eq('comment_id', comment.id)
  return new Response(JSON.stringify({ success: true, data: { comment_id: comment.id, decision } }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}
```
Router: in the POST branch, `if (pathname.endsWith('/approve')) return handleReviewComment(req, services, 'approve')` and `/discard` likewise, before the create fallback. Imports: `DISCIPLER_USER_ID` and `pushUsers`.

- [ ] **Step 3: Admin delete for posts and comments**

In both DELETE handlers, replace the `if (!isMentor) throw ...` with:
```ts
    if (!isMentor) {
      const { data: profile } = await db.from('user_profiles').select('is_admin').eq('id', user.id).maybeSingle()
      if (profile?.is_admin !== true) throw new AppError('PERMISSION_DENIED', 'Cannot delete this post', 403)
    }
```
(message `'Cannot delete this comment'` in the comments function). When a deleted comment belongs to Discipler, also `await db.from('discipler_activity').update({ reviewed_by: user.id, reviewed_at: new Date().toISOString() }).eq('comment_id', body.comment_id)`.

- [ ] **Step 4: Report guard**

In `handleCreateReport`, after validation, look up the target author:
```ts
  const table = body.content_type === 'post' ? 'fellowship_posts' : 'fellowship_comments'
  const { data: target } = await db.from(table).select('author_user_id').eq('id', body.content_id).maybeSingle()
  if (target?.author_user_id === DISCIPLER_USER_ID) throw new AppError('VALIDATION_ERROR', 'Discipler content cannot be reported; ask a mentor to remove it', 400)
```

- [ ] **Step 5: Verify**

Type check. Set the fellowship to `review` mode, post a tagged question as Rahul, run the reply route (Task 6 command), GET comments as Rahul → the draft is absent; as Anna → present with `is_pending_review: true`; POST `/approve` as Anna → 200; GET as Rahul → present. Report the Discipler comment as Rahul → 400.

- [ ] **Step 6: Commit**

```bash
git add backend/supabase/functions/fellowship-comments/index.ts backend/supabase/functions/fellowship-posts/index.ts
git commit -m "feat(discipler): review mode approve/discard, admin delete, report guard"
```

---

### Task 9: Blocks reject the system user

**Files:**
- Modify: `backend/supabase/functions/fellowship-blocks/index.ts` (POST handler)

- [ ] **Step 1: Add the guard** right after `blocked_user_id` validation:
```ts
  if (body.blocked_user_id === DISCIPLER_USER_ID) throw new AppError('VALIDATION_ERROR', 'Discipler cannot be blocked; mentors can turn it off in fellowship settings', 400)
```
import `DISCIPLER_USER_ID` from `../_shared/utils/discipler.ts`.

- [ ] **Step 2: Verify** — POST block with the Discipler id → 400. Type check.

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/functions/fellowship-blocks/index.ts
git commit -m "fix(fellowship-blocks): refuse blocking the Discipler system user"
```

---

### Task 10: Promote and demote mentors

**Files:**
- Modify: `backend/supabase/functions/fellowship-members/index.ts` (router ~332-353; add handlers after `handleTransferMentor`)

**Interfaces:**
- Produces: `POST /fellowship-members/promote { fellowship_id, user_id }`, `POST /fellowship-members/demote { fellowship_id, user_id }` (mentor or admin). Demoting the owner (`fellowships.mentor_user_id`) → 400. GET members response adds `is_owner`.

- [ ] **Step 1: Add the handler**

```ts
async function handleChangeMentorRole(req: Request, services: ServiceContainer, to: 'mentor' | 'member'): Promise<Response> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error: authError } = await services.supabaseServiceClient.auth.getUser(authHeader.replace('Bearer ', ''))
  if (authError || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)
  let body: { fellowship_id: string; user_id: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.fellowship_id) throw new AppError('VALIDATION_ERROR', 'fellowship_id is required', 400)
  if (!body.user_id) throw new AppError('VALIDATION_ERROR', 'user_id is required', 400)
  const db = services.supabaseServiceClient

  const [{ data: isMentor }, { data: profile }, { data: fellowship }] = await Promise.all([
    db.rpc('is_fellowship_mentor', { p_fellowship_id: body.fellowship_id, p_user_id: user.id }),
    db.from('user_profiles').select('is_admin').eq('id', user.id).maybeSingle(),
    db.from('fellowships').select('mentor_user_id').eq('id', body.fellowship_id).maybeSingle(),
  ])
  if (!isMentor && profile?.is_admin !== true) throw new AppError('PERMISSION_DENIED', 'Mentor access required', 403)
  if (!fellowship) throw new AppError('NOT_FOUND', 'Fellowship not found', 404)
  if (to === 'member' && body.user_id === fellowship.mentor_user_id) throw new AppError('VALIDATION_ERROR', 'The owner cannot be demoted — transfer ownership first', 400)

  const { data: target } = await db.from('fellowship_members').select('role').eq('fellowship_id', body.fellowship_id).eq('user_id', body.user_id).eq('is_active', true).maybeSingle()
  if (!target) throw new AppError('NOT_FOUND', 'Target user is not an active member', 404)
  if (target.role === to) return new Response(JSON.stringify({ success: true, message: 'No change' }), { status: 200, headers: { 'Content-Type': 'application/json' } })

  const { error } = await db.from('fellowship_members').update({ role: to }).eq('fellowship_id', body.fellowship_id).eq('user_id', body.user_id)
  if (error) { console.error('[fellowship-members/role] Update error:', error); throw new AppError('DATABASE_ERROR', 'Failed to change role', 500) }
  return new Response(JSON.stringify({ success: true, data: { user_id: body.user_id, role: to } }), { status: 200, headers: { 'Content-Type': 'application/json' } })
}
```
Router: `if (pathname.endsWith('/promote')) return handleChangeMentorRole(req, services, 'mentor')` and `/demote` → `'member'`. In `handleListMembers`, fetch `fellowships.mentor_user_id` and add `is_owner: m.user_id === ownerId` to each member.

- [ ] **Step 2: Verify** — as Anna promote Rahul → 200; GET members shows two mentors; demote Anna → 400 (owner); as Rahul (now mentor) demote himself → 200. Type check.

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/functions/fellowship-members/index.ts
git commit -m "feat(fellowship-members): promote and demote mentors, expose owner"
```

---

### Task 11: Drift tests and client type allowlist

**Files:**
- Modify: `frontend/lib/core/services/notification_service.dart:598-618` (`validTypes`)
- Run: `backend/supabase/functions/_shared/services/push-type-routing-drift.test.ts`

- [ ] **Step 1: Run the drift test to see it fail**

`cd backend/supabase/functions/_shared/services && deno test --allow-read push-type-routing-drift.test.ts` → FAIL listing `fellowship_daily_post, fellowship_discipler_activity, fellowship_discipler_reply`.

- [ ] **Step 2: Add the three types to the Dart set**

```dart
      'fellowship_member_joined',
      'fellowship_daily_post',
      'fellowship_discipler_reply',
      'fellowship_discipler_activity',
    };
```
(Routing cases are added in Plan 04 Task 12; the set alone satisfies the drift test.)

- [ ] **Step 3: Run all backend tests touched by this plan**

```bash
cd backend/supabase/functions
deno test _shared/utils/discipler.test.ts _shared/prompts/discipler-prompt.test.ts
deno test --allow-env _shared/services/discipler-service.test.ts fellowship-posts/discipler-reply.test.ts
deno test --allow-read _shared/services/push-type-routing-drift.test.ts _shared/services/notification-type-constraint.test.ts
cd ../.. && sh scripts/check-quick.sh
```
Expected: all PASS, `✅`.

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/core/services/notification_service.dart
git commit -m "chore(notifications): register Discipler push types in the client allowlist"
```

---

## Self-Review Notes

- Spec §2 gates, mention, question, react, context, prompt, output schema, review mode, budgets, oversight pushes: Tasks 1, 2, 5, 6, 8.
- Spec §4 admin/mentor rules: Task 7. Spec §5 promote/demote, ask-a-mentor push to all mentors: Tasks 5, 10.
- Spec §8 cleanups on the backend (system post removal, invite-join push): Task 7.
- Spec §10 routes: all present; no new function directories created.
- Type names are consistent across tasks: `FellowshipDisciplerSettings`, `DisciplerFellowshipRow`, `DisciplerOutput`, `Classification`, `handleDisciplerReply`, `handleNotify`, `handleReviewComment`, `handleChangeMentorRole`, `handleDisciplerActivity`.
- Known follow-up outside scope: `fellowship-meetings` logs `'meeting_invite'` to `notification_logs`, which the CHECK rejects silently. Not fixed here.
