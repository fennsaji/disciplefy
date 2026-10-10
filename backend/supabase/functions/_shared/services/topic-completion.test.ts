import { assertEquals, assertRejects } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  advancedLessonPosition,
  isRecentCompletion,
  lessonTopicMatches,
  nextFellowshipStudyState,
  recordTopicCompletion,
  reportedCompletion,
} from './topic-completion.ts'

/** Records every rpc call in order and answers from [responses]. */
function fakeClient(responses: Record<string, { data: unknown; error: unknown }>) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = []
  return {
    calls,
    rpc(name: string, args: Record<string, unknown>) {
      calls.push({ name, args })
      return Promise.resolve(responses[name] ?? { data: null, error: null })
    },
  }
}

const COMPLETED = {
  data: [{ progress_id: 'p1', xp_earned: 50, is_first_completion: true, topic_title: 'T' }],
  error: null,
}

Deno.test('the path is ensured started before the topic is completed, so the trigger counts it', async () => {
  const db = fakeClient({ complete_topic_progress: COMPLETED, ensure_learning_path_started: { data: 'path', error: null } })
  const result = await recordTopicCompletion(db, { userId: 'u', topicId: 't', timeSpentSeconds: 12, isGuest: false })
  assertEquals(db.calls.map((c) => c.name), ['ensure_learning_path_started', 'complete_topic_progress'])
  assertEquals(db.calls[1].args, { p_user_id: 'u', p_topic_id: 't', p_time_spent_seconds: 12 })
  assertEquals(result.is_first_completion, true)
  assertEquals(result.xp_earned, 50)
})

Deno.test('a guest is never auto-enrolled: guests enrol only through learning-paths', async () => {
  const db = fakeClient({ complete_topic_progress: COMPLETED })
  await recordTopicCompletion(db, { userId: 'g', topicId: 't', timeSpentSeconds: 0, isGuest: true })
  assertEquals(db.calls.map((c) => c.name), ['complete_topic_progress'])
})

Deno.test('a failed path ensure does not block the completion', async () => {
  const db = fakeClient({
    complete_topic_progress: COMPLETED,
    ensure_learning_path_started: { data: null, error: { message: 'boom' } },
  })
  const result = await recordTopicCompletion(db, { userId: 'u', topicId: 't', timeSpentSeconds: 0, isGuest: false })
  assertEquals(result.progress_id, 'p1')
})

Deno.test('a failed completion rpc throws', async () => {
  const db = fakeClient({ complete_topic_progress: { data: null, error: { message: 'boom' } } })
  await assertRejects(() =>
    recordTopicCompletion(db, { userId: 'u', topicId: 't', timeSpentSeconds: 0, isGuest: false })
  )
})

Deno.test('fellowship auto-advance compares the lesson topic id, not the join-row id', () => {
  assertEquals(lessonTopicMatches({ id: 'row-1', topic_id: 'topic-1' }, 'topic-1'), true)
  assertEquals(lessonTopicMatches({ id: 'topic-1', topic_id: 'other' }, 'topic-1'), false)
  assertEquals(lessonTopicMatches(null, 'topic-1'), false)
})

Deno.test('next fellowship study state advances, then completes on the last lesson', () => {
  assertEquals(nextFellowshipStudyState(0, 3), { isComplete: false, newGuideIndex: 1 })
  assertEquals(nextFellowshipStudyState(2, 3), { isComplete: true, newGuideIndex: 2 })
})

Deno.test('the lesson that last moved a study is the previous index, or the current one once complete', () => {
  assertEquals(advancedLessonPosition({ current_guide_index: 3, completed_at: null }), 2)
  assertEquals(advancedLessonPosition({ current_guide_index: 4, completed_at: '2026-10-07T00:00:00Z' }), 4)
  assertEquals(advancedLessonPosition({ current_guide_index: 0, completed_at: null }), null)
})

Deno.test('a completion is recent within the window only', () => {
  const now = new Date('2026-10-07T12:00:00Z')
  assertEquals(isRecentCompletion('2026-10-07T11:59:00Z', now), true)
  assertEquals(isRecentCompletion('2026-10-07T11:50:00Z', now), false)
  assertEquals(isRecentCompletion(null, now), false)
  assertEquals(isRecentCompletion('not a date', now), false)
})

Deno.test('a completion mark-study-guide-complete recorded moments ago is reported with its stored xp', () => {
  const now = new Date('2026-10-07T12:00:00Z')
  const repeat = { progress_id: 'p1', xp_earned: 0, is_first_completion: false, topic_title: 'T' }
  assertEquals(
    reportedCompletion(repeat, { completed_at: '2026-10-07T11:59:30Z', xp_earned: 50 }, now),
    { progress_id: 'p1', xp_earned: 50, is_first_completion: true, topic_title: 'T' },
  )
  // An old completion stays a repeat with no XP.
  assertEquals(reportedCompletion(repeat, { completed_at: '2026-10-01T00:00:00Z', xp_earned: 50 }, now), repeat)
  assertEquals(reportedCompletion(repeat, null, now), repeat)
  // A first completion is reported as is.
  const first = { ...repeat, xp_earned: 50, is_first_completion: true }
  assertEquals(reportedCompletion(first, { completed_at: '2026-10-07T11:59:59Z', xp_earned: 50 }, now), first)
})
