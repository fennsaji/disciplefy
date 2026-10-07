// Run with: deno test learning-paths/batch-loaders.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  countCompletedPerPath,
  groupPathTranslations,
  loadCompletedTopicCounts,
  loadEnrolledPathIds,
  pathProgressPercentage,
  resolveShortTitle,
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
  assertEquals(map.get('a'), { title: 'A', description: null, short_title: null })
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

Deno.test('pathProgressPercentage reads every topic done as 100 without an enrollment row', () => {
  assertEquals(pathProgressPercentage(16, 16, 'romans', new Set()), 100)
  assertEquals(pathProgressPercentage(4, 16, 'romans', new Set()), 25)
  assertEquals(pathProgressPercentage(0, 16, 'romans', new Set(['romans'])), 100)
  assertEquals(pathProgressPercentage(0, 0, 'empty', new Set()), 0)
})

Deno.test('groupPathTranslations keeps short_title', () => {
  const grouped = groupPathTranslations(['p'], [
    { learning_path_id: 'p', title: 'പുതിയ വിശ്വാസിയുടെ അടിസ്ഥാനങ്ങൾ', description: 'd', short_title: 'വിശ്വാസ അടിസ്ഥാനങ്ങൾ' },
  ])
  assertEquals(grouped.get('p')?.short_title, 'വിശ്വാസ അടിസ്ഥാനങ്ങൾ')
})

Deno.test('resolveShortTitle: English uses the base short title', () => {
  assertEquals(resolveShortTitle('en', 'Sin, Repentance & Grace', undefined), 'Sin, Repentance & Grace')
  assertEquals(resolveShortTitle('en', null, undefined), null)
})

Deno.test('resolveShortTitle: a translated title never borrows the English short title', () => {
  const translated = { title: 'पाप, पश्चाताप और परमेश्वर का अनुग्रह', description: 'd', short_title: null }
  assertEquals(resolveShortTitle('hi', 'Sin, Repentance & Grace', translated), null)
  assertEquals(
    resolveShortTitle('hi', 'Sin, Repentance & Grace', { ...translated, short_title: 'पाप, पश्चाताप और अनुग्रह' }),
    'पाप, पश्चाताप और अनुग्रह',
  )
})

Deno.test('resolveShortTitle: without a translated title the English short title goes with the English title', () => {
  assertEquals(resolveShortTitle('ml', 'Short', null), 'Short')
  assertEquals(resolveShortTitle('ml', 'Short', { title: null, description: 'd', short_title: null }), 'Short')
})

Deno.test('resolveShortTitle: blank short titles read as none', () => {
  assertEquals(resolveShortTitle('en', '   ', undefined), null)
  assertEquals(resolveShortTitle('hi', 'Short', { title: 'T', description: 'd', short_title: '  ' }), null)
})
