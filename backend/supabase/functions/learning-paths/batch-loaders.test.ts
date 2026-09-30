// Run with: deno test learning-paths/batch-loaders.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  countCompletedPerPath,
  groupPathTranslations,
  loadCompletedTopicCounts,
  loadEnrolledPathIds,
} from './batch-loaders.ts'

/** Minimal chainable fake of a supabase-js query builder. */
function fakeClient(tables: Record<string, { data: unknown; error: unknown }>, calls: string[] = []) {
  return {
    from(table: string) {
      calls.push(table)
      const result = tables[table]
      const builder: Record<string, unknown> = {}
      for (const m of ['select', 'in', 'eq', 'not']) builder[m] = () => builder
      builder.then = (resolve: (v: unknown) => unknown) => resolve(result)
      return builder
    },
  }
}

Deno.test('countCompletedPerPath counts distinct completed topics per path, zero for none', () => {
  const counts = countCompletedPerPath(
    ['p1', 'p2', 'p3'],
    [
      { learning_path_id: 'p1', topic_id: 't1' },
      { learning_path_id: 'p1', topic_id: 't2' },
      { learning_path_id: 'p2', topic_id: 't1' },
      { learning_path_id: 'p2', topic_id: 't3' },
    ],
    [{ topic_id: 't1' }, { topic_id: 't1' }, { topic_id: 't2' }],
  )
  assertEquals(counts.get('p1'), 2)
  assertEquals(counts.get('p2'), 1) // topic shared across paths counts in each
  assertEquals(counts.get('p3'), 0)
})

Deno.test('groupPathTranslations maps single rows, null for missing or duplicated', () => {
  const map = groupPathTranslations(['a', 'b', 'c'], [
    { learning_path_id: 'a', title: 'A', description: null },
    { learning_path_id: 'c', title: 'C1', description: 'x' },
    { learning_path_id: 'c', title: 'C2', description: 'y' },
  ])
  assertEquals(map.get('a'), { title: 'A', description: null })
  assertEquals(map.get('b'), null)
  assertEquals(map.get('c'), null) // .single() failed on duplicates
})

Deno.test('loadCompletedTopicCounts uses two queries for all paths', async () => {
  const calls: string[] = []
  const client = fakeClient({
    learning_path_topics: {
      data: [
        { learning_path_id: 'p1', topic_id: 't1' },
        { learning_path_id: 'p2', topic_id: 't2' },
      ],
      error: null,
    },
    user_topic_progress: { data: [{ topic_id: 't2' }], error: null },
  }, calls)
  const counts = await loadCompletedTopicCounts(client, ['p1', 'p2', 'p1'], 'u')
  assertEquals(calls, ['learning_path_topics', 'user_topic_progress'])
  assertEquals(counts?.get('p1'), 0)
  assertEquals(counts?.get('p2'), 1)
})

Deno.test('loadCompletedTopicCounts returns null on error so callers fall back', async () => {
  const client = fakeClient({ learning_path_topics: { data: null, error: { code: 'X' } } })
  assertEquals(await loadCompletedTopicCounts(client, ['p1'], 'u'), null)
})

Deno.test('loadEnrolledPathIds returns the enrolled set, empty without ids', async () => {
  const client = fakeClient({ user_learning_path_progress: { data: [{ learning_path_id: 'p2' }], error: null } })
  assertEquals(await loadEnrolledPathIds(client, ['p1', 'p2'], 'u'), new Set(['p2']))
  assertEquals(await loadEnrolledPathIds(client, [], 'u'), new Set())
})
