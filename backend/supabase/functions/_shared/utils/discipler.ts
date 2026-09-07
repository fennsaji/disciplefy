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
  authorUserId: string
  /** Author asked Discipler not to answer this post. */
  disciplerOptOut?: boolean
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
  const { content, postType, topicId, authorUserId, settings, globalEnabled, disciplerOptOut } = input
  if (!globalEnabled || !settings.discipler_allowed) return null
  if (authorUserId === DISCIPLER_USER_ID || authorUserId === DISCIPLER_SYSTEM_USER_ID) return null
  if (postType === 'daily') return null

  if (mentionsDiscipler(content)) {
    return settings.discipler_reply_mode === 'off' ? null : { trigger: 'mention', delayMinutes: 0 }
  }

  // Mentors' own questions are answered too. Deference to a human is handled
  // downstream instead: the reply worker drops a queued reply if a mentor has
  // answered the post within the fellowship's wait window. A mentor who wants
  // this one question left to the group opts out per post; an explicit
  // @Discipler above still wins, being the clearer intent.
  if (!disciplerOptOut && replyEnabled(settings, globalEnabled) && isQuestionLike(content, postType)) {
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
