// Run with: deno test _shared/repositories/path-topic-ids.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { excludePathLessons } from './path-topic-ids.ts'

Deno.test('drops guides whose topic is a path lesson, keeps typed studies', () => {
  const rows = [
    { id: 'a', study_guides: { topic_id: null } },
    { id: 'b', study_guides: { topic_id: 'lesson-1' } },
    { id: 'c', study_guides: { topic_id: 'recommended-only' } },
  ]
  assertEquals(excludePathLessons(rows, new Set(['lesson-1'])).map(r => r.id), ['a', 'c'])
})

import { loadPathTopicIds, resetPathTopicIdsCache } from './path-topic-ids.ts'

// deno-lint-ignore no-explicit-any
function fakeClient(result: () => any) {
  let calls = 0
  const client = {
    from: () => ({ select: () => { calls++; return Promise.resolve(result()) } })
  }
  // deno-lint-ignore no-explicit-any
  return { client: client as any, calls: () => calls }
}

Deno.test('loader caches within TTL and refetches after it', async () => {
  resetPathTopicIdsCache()
  const f = fakeClient(() => ({ data: [{ topic_id: 't1' }], error: null }))
  let t = 1000
  const now = () => t
  assertEquals([...await loadPathTopicIds(f.client, now)], ['t1'])
  t += 60_000
  await loadPathTopicIds(f.client, now)
  assertEquals(f.calls(), 1)
  t += 5 * 60_000
  await loadPathTopicIds(f.client, now)
  assertEquals(f.calls(), 2)
})

Deno.test('loader returns empty set on error and does not cache it', async () => {
  resetPathTopicIdsCache()
  let fail = true
  const f = fakeClient(() => fail
    ? { data: null, error: { message: 'boom' } }
    : { data: [{ topic_id: 't1' }], error: null })
  assertEquals((await loadPathTopicIds(f.client, () => 1)).size, 0)
  fail = false
  assertEquals([...await loadPathTopicIds(f.client, () => 2)], ['t1'])
  assertEquals(f.calls(), 2)
})
