// Run with: deno test learning-paths/next-lesson.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildNextLesson, countCompleted, milestonePositions } from './next-lesson.ts'

const rows = [3, 1, 2].map(p => ({ topic_id: `t${p}`, position: p * 10, is_milestone: p === 3, title: `L${p}`, description: '', input_type: 'topic' }))

Deno.test('next lesson is the first incomplete by position, numbered 1-based', () => {
  assertEquals(buildNextLesson(rows, new Set(['t1'])), { topic_id: 't2', title: 'L2', description: '', input_type: 'topic', lesson_number: 2, lesson_total: 3 })
})
Deno.test('all complete -> null', () => {
  assertEquals(buildNextLesson(rows, new Set(['t1', 't2', 't3'])), null)
})
Deno.test('milestones are lesson numbers', () => {
  assertEquals(milestonePositions(rows), [3])
})
Deno.test('zero topics', () => {
  assertEquals(buildNextLesson([], new Set()), null)
  assertEquals(milestonePositions([]), [])
  assertEquals(countCompleted([], new Set(['x'])), 0)
})
Deno.test('milestone in the middle uses sorted position', () => {
  const r = rows.map(t => ({ ...t, is_milestone: t.topic_id === 't2' }))
  assertEquals(milestonePositions(r), [2])
})
Deno.test('topics_completed counts only this path topic ids', () => {
  assertEquals(countCompleted(rows, new Set(['t1', 'other', 'x'])), 1)
})

import { buildRecommendedExtras } from './next-lesson.ts'

Deno.test('null topics (zero active topics) still return the full shape', () => {
  for (const signedIn of [true, false]) {
    assertEquals(buildRecommendedExtras(null, signedIn, 'P'), { next_lesson: null, topics_completed: 0, milestone_positions: [] })
  }
})
Deno.test('guest has nothing completed; blank title falls back', () => {
  const raw = [{ topic_id: 'a', position: 1, is_milestone: false, title: '  ', is_completed: true }]
  const g = buildRecommendedExtras(raw, false, 'Path')
  assertEquals(g.topics_completed, 0)
  assertEquals(g.next_lesson?.title, 'Path')
  assertEquals(buildRecommendedExtras(raw, true, 'Path').next_lesson, null)
})
