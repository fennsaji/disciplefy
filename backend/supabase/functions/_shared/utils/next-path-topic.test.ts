// Run with: deno test next-path-topic.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  firstUnfinishedTopic,
  isPathFinished,
  pickContinueLearningTopic,
  type PathTopicRow,
} from './next-path-topic.ts'

function lessons(pathId: string, count: number, prefix: string): PathTopicRow[] {
  return Array.from({ length: count }, (_, i) => ({
    learning_path_id: pathId,
    topic_id: `${prefix}-${i + 1}`,
    position: i,
    title: `${prefix} ${i + 1}`,
    description: '',
    category: 'Book Study',
  }))
}

const romans = lessons('romans', 16, 'Romans')
const allRomansDone = new Set(romans.map((t) => t.topic_id))

/**
 * The production report: Romans path finished 16/16, but its progress row was
 * created after the lessons were done (Review auto-enrols), so it still reads
 * cursor 0 / completed_at NULL. The push named Romans 1.
 */
Deno.test('a finished path with a stale cursor-0 row suggests nothing', () => {
  const picked = pickContinueLearningTopic(
    [{ learning_path_id: 'romans', current_topic_position: 0 }],
    romans,
    allRomansDone,
  )
  assertEquals(picked, null)
})

Deno.test('a finished path hands over to the next enrolled path with work left', () => {
  const john = lessons('john', 5, 'John')
  const done = new Set([...allRomansDone, 'John-1'])
  const picked = pickContinueLearningTopic(
    [
      { learning_path_id: 'romans', current_topic_position: 0 },
      { learning_path_id: 'john', current_topic_position: 0 },
    ],
    [...romans, ...john],
    done,
  )
  assertEquals(picked?.topic_id, 'John-2')
})

Deno.test('a completed lesson under the cursor is skipped', () => {
  // Cursor left on lesson 1 although 1-3 are done.
  const done = new Set(['Romans-1', 'Romans-2', 'Romans-3'])
  const picked = pickContinueLearningTopic(
    [{ learning_path_id: 'romans', current_topic_position: 0 }],
    romans,
    done,
  )
  assertEquals(picked?.topic_id, 'Romans-4')
})

Deno.test('the user keeps their place when they skipped ahead', () => {
  // Did 1 and 5, cursor sits after lesson 5 (position 5 = lesson 6); lessons
  // 2-4 are unfinished but the user is not sent back to them.
  const done = new Set(['Romans-1', 'Romans-5'])
  const picked = pickContinueLearningTopic(
    [{ learning_path_id: 'romans', current_topic_position: 5 }],
    romans,
    done,
  )
  assertEquals(picked?.topic_id, 'Romans-6')
})

Deno.test('with nothing left after the cursor, the earliest unfinished lesson wins', () => {
  const done = new Set(romans.filter((t) => t.topic_id !== 'Romans-2').map((t) => t.topic_id))
  const picked = pickContinueLearningTopic(
    [{ learning_path_id: 'romans', current_topic_position: 15 }],
    romans,
    done,
  )
  assertEquals(picked?.topic_id, 'Romans-2')
})

Deno.test('a path with no visible lessons is skipped, not treated as unfinished', () => {
  assertEquals(
    pickContinueLearningTopic([{ learning_path_id: 'empty', current_topic_position: 0 }], romans, new Set()),
    null,
  )
})

Deno.test('null cursor reads as the start of the path', () => {
  assertEquals(
    pickContinueLearningTopic([{ learning_path_id: 'romans', current_topic_position: null }], romans, new Set())
      ?.topic_id,
    'Romans-1',
  )
})

Deno.test('firstUnfinishedTopic / isPathFinished', () => {
  assertEquals(firstUnfinishedTopic(romans, allRomansDone), null)
  assertEquals(firstUnfinishedTopic(romans, new Set(['Romans-1']))?.topic_id, 'Romans-2')
  assertEquals(isPathFinished(romans, allRomansDone), true)
  assertEquals(isPathFinished(romans, new Set(['Romans-1'])), false)
  assertEquals(isPathFinished([], new Set()), false)
})
