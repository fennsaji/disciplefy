// Run with: deno test _shared/topic-selector.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { getLocalizedTopicsContent, mergeTopicTranslations } from './topic-selector.ts'

const topics = [
  { id: 't1', title: 'One', description: 'd1', category: 'c', display_order: 1 },
  { id: 't2', title: 'Two', description: 'd2', category: 'c', display_order: 2 },
  { id: 't3', title: 'Three', description: 'd3', category: 'c', display_order: 3 },
  // deno-lint-ignore no-explicit-any
] as any

Deno.test('mergeTopicTranslations keeps order, uses rows as-is, falls back per topic', () => {
  const out = mergeTopicTranslations(topics, [
    { topic_id: 't2', title: 'दो', description: 'विवरण' },
    { topic_id: 't3', title: 'x', description: 'y' },
    { topic_id: 't3', title: 'z', description: 'w' },
  ])
  assertEquals(out, [
    { title: 'One', description: 'd1' },
    { title: 'दो', description: 'विवरण' },
    { title: 'Three', description: 'd3' }, // duplicate rows: .single() fell back
  ])
})

Deno.test('getLocalizedTopicsContent: English skips the query; errors fall back', async () => {
  let queried = 0
  const failing = {
    from() {
      queried++
      const b: Record<string, unknown> = {}
      b.select = () => b
      b.in = () => b
      b.eq = () => Promise.resolve({ data: null, error: { code: 'X' } })
      return b
    },
    // deno-lint-ignore no-explicit-any
  } as any
  const en = await getLocalizedTopicsContent(failing, topics, 'en')
  assertEquals(queried, 0)
  assertEquals(en[0], { title: 'One', description: 'd1' })
  const hi = await getLocalizedTopicsContent(failing, topics, 'hi')
  assertEquals(queried, 1)
  assertEquals(hi.map((t) => t.title), ['One', 'Two', 'Three'])
})
