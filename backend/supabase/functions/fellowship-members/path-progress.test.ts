// Run with: deno test fellowship-members/path-progress.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { countPathTopicsCompleted } from './path-progress.ts'

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

Deno.test('counts each member\'s completed lessons on the path, 0 for none', async () => {
  const client = fakeClient({
    learning_path_topics: { data: [1, 2, 3, 4, 5].map((n) => ({ topic_id: `t${n}` })), error: null },
    user_topic_progress: {
      data: [
        ...[1, 2, 3, 4, 5].map((n) => ({ user_id: 'mentor', topic_id: `t${n}` })),
        { user_id: 'member', topic_id: 't1' },
      ],
      error: null,
    },
  })
  const counts = await countPathTopicsCompleted(client, 'rooted', ['mentor', 'member', 'new'])
  assertEquals(counts.get('mentor'), 5)
  assertEquals(counts.get('member'), 1)
  assertEquals(counts.get('new'), 0)
})

Deno.test('duplicate topics or progress rows never exceed the path length', async () => {
  const client = fakeClient({
    learning_path_topics: { data: [{ topic_id: 't1' }, { topic_id: 't1' }, { topic_id: 't2' }], error: null },
    user_topic_progress: {
      data: [
        { user_id: 'u', topic_id: 't1' },
        { user_id: 'u', topic_id: 't1' },
        { user_id: 'u', topic_id: 't2' },
      ],
      error: null,
    },
  })
  const counts = await countPathTopicsCompleted(client, 'p', ['u'])
  assertEquals(counts.get('u'), 2)
})

Deno.test('no members or no lessons skip the progress query', async () => {
  const calls: string[] = []
  const empty = fakeClient({ learning_path_topics: { data: [], error: null } }, calls)
  assertEquals((await countPathTopicsCompleted(empty, 'p', [])).size, 0)
  assertEquals(calls, [])
  const counts = await countPathTopicsCompleted(empty, 'p', ['u'])
  assertEquals(counts.get('u'), 0)
  assertEquals(calls, ['learning_path_topics'])
})
