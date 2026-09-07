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

// ---------------------------------------------------------------------------
// Daily teaser
// ---------------------------------------------------------------------------

export interface DailyTeaserPromptInput {
  topicTitle: string
  pathTitle: string
  language: 'en' | 'hi' | 'ml'
  summary: string
  verse?: string
  question?: string
}

export interface DailyTeaserOutput {
  hook: string
  body: string
}

const TEASER_LANGUAGE_NAMES: Record<DailyTeaserPromptInput['language'], string> = {
  en: 'English',
  hi: 'Hindi (Devanagari script)',
  ml: 'Malayalam (Malayalam script)',
}

export function buildDailyTeaserSystemPrompt(): string {
  return `${THEOLOGICAL_FOUNDATION}

You are Discipler, an AI helper inside a Disciplefy fellowship group. You are not a human and never claim to be.

TASK: Write a short teaser that makes a member want to open today's study post. Return ONE JSON object:
{
  "hook": string,
  "body": string
}

AUDIENCE & TONE: A small church WhatsApp-style group reading on a phone. Warm, direct — like a friend who just read something that moved them. Write in second person.

RULES:
- "hook": ONE sentence, at most 90 characters. No emoji, no quotation marks, no exclamation-mark spam. Do not restate the topic title. Name a tension or a felt need that the lesson answers (e.g. "You're not what your worst day says you are.").
- "body": 1–2 sentences, at most 220 characters. Tie it to ordinary life — work, family, worry, a daily habit. Do NOT summarise the study guide. Do NOT quote the verse text (copyright) — you may name the Bible reference. No promises of health, wealth, or outcomes. No unbiblical claims.
- Write entirely in the requested language's native script. Never mix languages within the response.
- Output strictly the JSON object above and nothing else — no markdown fences, no commentary.`
}

export function buildDailyTeaserUserMessage(input: DailyTeaserPromptInput): string {
  const lines = [
    `Language: ${TEASER_LANGUAGE_NAMES[input.language]} (write hook and body in this language)`,
    `Learning path: ${input.pathTitle}`,
    `Today's topic: ${input.topicTitle}`,
    `Summary (for grounding only — do not quote or summarise it back):\n${input.summary}`,
  ]
  if (input.verse) lines.push(`Reference (name only, never quote the text): ${input.verse}`)
  if (input.question) lines.push(`Reflection question (for grounding only): ${input.question}`)
  return lines.join('\n\n')
}

export function parseDailyTeaserOutput(raw: string): DailyTeaserOutput {
  let parsed: Record<string, unknown>
  try {
    parsed = JSON.parse(cleanJSONResponse(raw)) as Record<string, unknown>
  } catch {
    throw new Error('TEASER_PARSE: not JSON')
  }
  const hook = parsed.hook
  const body = parsed.body
  if (typeof hook !== 'string' || hook.trim().length === 0 || hook.trim().length > 120) {
    throw new Error('TEASER_PARSE: bad hook')
  }
  if (typeof body !== 'string' || body.trim().length === 0 || body.trim().length > 300) {
    throw new Error('TEASER_PARSE: bad body')
  }
  return { hook: hook.trim(), body: body.trim() }
}
