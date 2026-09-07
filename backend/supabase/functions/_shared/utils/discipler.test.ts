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
  postType: 'general', topicId: null,
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
  const c = classifyPost({ ...base, content: '@Discipler is fasting required?' })
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

Deno.test('classifyPost: a mentor\'s own question is answered like anyone else\'s', () => {
  // Deference to a human answer is the reply worker's job, not the classifier's.
  assertEquals(classifyPost({ ...base, content: 'Is fasting required for believers?' }),
    { trigger: 'question', delayMinutes: 30 })
})

Deno.test('classifyPost: opting out silences the question trigger, not a mention', () => {
  const q = 'Is fasting required for believers?'
  assertEquals(classifyPost({ ...base, content: q, disciplerOptOut: true }), null)
  // An explicit tag is the clearer intent, so it still answers.
  assertEquals(classifyPost({ ...base, content: '@Discipler ' + q, disciplerOptOut: true }),
    { trigger: 'mention', delayMinutes: 0 })
  // Absent or false behaves exactly as before.
  assertEquals(classifyPost({ ...base, content: q, disciplerOptOut: false }),
    { trigger: 'question', delayMinutes: 30 })
})

Deno.test('classifyPost: off mode, global off, system author → null or react', () => {
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
