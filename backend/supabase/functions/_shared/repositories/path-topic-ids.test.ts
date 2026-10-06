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
