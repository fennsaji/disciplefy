// Run with: deno test teaser-service.test.ts
import { assertEquals, assertNotEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { getOrCreateTeaser, teaserCacheKey, variantForAudience } from './teaser-service.ts'

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

/**
 * Minimal stand-in for the chained supabase-js query builder that
 * getOrCreateTeaser calls: `.from(table).select(...).eq(...).eq(...).order(...)`,
 * `.update(...).eq(...)`, and `.insert(...)`.
 *
 * The initial list query (no `.single()` in the chain) always resolves empty —
 * it stands in for the moment two concurrent requests both see an empty cache,
 * which is the race this file is testing. `.single()` (the post-conflict
 * re-fetch) reads `table` for real, and `insert` enforces the same
 * (topic_key, language, variant) unique constraint the real table has.
 */
function fakeDb(table: Record<string, unknown>[]) {
  function builder() {
    const filters: [string, unknown][] = []
    const api = {
      eq(col: string, value: unknown) {
        filters.push([col, value])
        return api
      },
      order() {
        return api
      },
      then(resolve: (v: { data: Record<string, unknown>[] }) => void) {
        resolve({ data: [] })
      },
      // deno-lint-ignore no-explicit-any
      single(): any {
        const matched = table.filter((r) => filters.every(([c, v]) => r[c] === v))
        return Promise.resolve({ data: matched[0] ?? null })
      },
    }
    return api
  }

  return {
    from(_name: string) {
      return {
        select() {
          return builder()
        },
        update() {
          return { eq: () => ({ then: (_ok: unknown, onErr: () => void) => onErr?.() }) }
        },
        insert(row: Record<string, unknown>) {
          const conflict = table.some((r) =>
            r.topic_key === row.topic_key && r.language === row.language && r.variant === row.variant
          )
          if (conflict) return Promise.resolve({ error: { code: '23505', message: 'duplicate key' } })
          table.push(row)
          return Promise.resolve({ error: null })
        },
      }
    },
  }
}

Deno.test('losing the insert race returns the winner\'s wording, not this call\'s own generation', async () => {
  // Reproduces two fellowships requesting a brand-new topic at once: both see
  // an empty cache, both call the LLM, and the LLM is non-deterministic, so
  // the two generations differ. The loser must still surface the winner's
  // stored teaser rather than its own.
  const table: Record<string, unknown>[] = []
  const db = fakeDb(table)

  // The winner's insert has already landed by the time the loser tries.
  table.push({
    id: '1', topic_key: 't-1', language: 'en', variant: 0,
    hook: 'Winner headline', body: 'Winner body', model: 'model-a', use_count: 1,
  })

  const llmService = {
    // deno-lint-ignore no-explicit-any
    generateDailyTeaser: () => Promise.resolve({
      content: JSON.stringify({ hook: 'Loser headline', body: 'Loser body' }),
      model: 'model-b',
    }),
  }

  const lesson = {
    topicId: 't-1',
    topicTitle: 'Who is Jesus Christ?',
    pathTitle: 'New Believer',
    language: 'en' as const,
    summary: 'summary',
  }

  // This call's own insert must lose to the row already in the table.
  const result = await getOrCreateTeaser(db, llmService, lesson, 'fellowship-b')

  assertEquals(result.hook, 'Winner headline')
  assertEquals(result.body, 'Winner body')
  assertEquals(result.model, 'model-a')
  assertEquals(result.cached, true)
})
