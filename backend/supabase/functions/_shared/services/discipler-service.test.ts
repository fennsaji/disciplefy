// backend/supabase/functions/_shared/services/discipler-service.test.ts
// Run with: deno test --allow-env discipler-service.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { enqueueReply, reactAsDiscipler } from './discipler-service.ts'

function fakeDb(log: string[]) {
  const chain = (table: string) => {
    const q: Record<string, unknown> = {}
    const self = () => q
    q.select = self; q.eq = self; q.maybeSingle = () => Promise.resolve({ data: null, error: null })
    q.insert = (row: unknown) => { log.push(`${table}:insert:${JSON.stringify(row)}`); return q }
    q.upsert = (row: unknown, o: unknown) => { log.push(`${table}:upsert:${JSON.stringify(row)}:${JSON.stringify(o)}`); return Promise.resolve({ error: null }) }
    q.update = (row: unknown) => { log.push(`${table}:update:${JSON.stringify(row)}`); return q }
    q.then = (res: (v: unknown) => void) => res({ data: null, error: null })
    return q
  }
  return { from: chain } as unknown as import('@supabase/supabase-js').SupabaseClient
}

Deno.test('reactAsDiscipler inserts a reaction and bumps the count', async () => {
  const log: string[] = []
  const counts = await reactAsDiscipler(fakeDb(log), {
    postId: 'p1', fellowshipId: 'f1', reaction: 'amen', currentCounts: { amen: 2 },
  })
  assertEquals(counts, { amen: 3 })
  assertEquals(log.some((l) => l.startsWith('fellowship_reactions:insert') && l.includes('00000000-0000-4000-8000-00000000d15c')), true)
  assertEquals(log.some((l) => l.startsWith('fellowship_posts:update') && l.includes('"amen":3')), true)
})

Deno.test('enqueueReply upserts on the (post, comment) target', async () => {
  const log: string[] = []
  await enqueueReply(fakeDb(log), { postId: 'p1', fellowshipId: 'f1', trigger: 'question', runAfter: '2026-09-06T00:30:00.000Z' })
  assertEquals(log.length, 1)
  assertEquals(log[0].includes('"trigger":"question"'), true)
  assertEquals(log[0].includes('ignoreDuplicates'), true)
})
