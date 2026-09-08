// Run with: deno test teaser-service.test.ts
import { assertEquals, assertNotEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { teaserCacheKey, variantForAudience } from './teaser-service.ts'

Deno.test('the topic id is the cache key when the caller knows it', async () => {
  assertEquals(
    await teaserCacheKey({ topicId: 't-123', pathTitle: 'Sin & Repentance', topicTitle: 'The Wages of Sin' }),
    't-123',
  )
})

Deno.test('without a topic id the titles hash to one stable key', async () => {
  const a = await teaserCacheKey({ pathTitle: 'Sin & Repentance', topicTitle: 'The Wages of Sin' })
  // The same lesson, differently cased and padded by another caller.
  const b = await teaserCacheKey({ pathTitle: '  sin & repentance ', topicTitle: 'the wages of sin' })
  assertEquals(a, b)
  assertEquals(a.length, 64)

  assertNotEquals(a, await teaserCacheKey({ pathTitle: 'Sin & Repentance', topicTitle: 'Grace Abounds' }))
})

Deno.test('one stored wording serves every audience, so nothing is regenerated', () => {
  // The usual case: a lesson has exactly one teaser and everyone reads it.
  assertEquals(variantForAudience('f0000000-0000-0000-0000-000000000001', 1), 0)
  assertEquals(variantForAudience('telegram-official-channel', 1), 0)
  assertEquals(variantForAudience('anything', 0), 0)
})

Deno.test('extra wordings, when seeded, are shared out and stay stable', () => {
  const pick = variantForAudience('f0000000-0000-0000-0000-000000000001', 3)
  assertEquals(variantForAudience('f0000000-0000-0000-0000-000000000001', 3), pick)
  assertEquals(pick >= 0 && pick < 3, true)

  const seen = new Set<number>()
  for (let i = 0; i < 60; i++) seen.add(variantForAudience(`f${i}-audience-${i % 7}`, 3))
  assertEquals(seen.size, 3)
})
