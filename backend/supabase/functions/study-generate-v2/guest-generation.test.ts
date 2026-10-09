import { assertEquals, assertRejects } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { assertGuestMayGenerate, guestMayGenerate, loadGuestGenerationScope } from './guest-generation.ts'

Deno.test('a full account is never limited here', () => {
  assertEquals(guestMayGenerate(false, false, [], [], []), true)
})

Deno.test('a guest may not generate anything that is not a verified catalogue lesson', () => {
  assertEquals(guestMayGenerate(true, false, ['p1'], ['p1'], ['p1']), false)
})

Deno.test('a guest may generate a lesson of an enrolled, guest-accessible path', () => {
  assertEquals(guestMayGenerate(true, true, ['p1'], ['p1'], ['p1']), true)
})

Deno.test('enrolled but not guest-accessible, or accessible but not enrolled, is refused', () => {
  assertEquals(guestMayGenerate(true, true, ['p1'], ['p1'], []), false)
  assertEquals(guestMayGenerate(true, true, [], ['p1'], ['p1']), false)
  assertEquals(guestMayGenerate(true, true, ['p2'], ['p1'], ['p1', 'p2']), false)
  assertEquals(guestMayGenerate(true, true, ['p1'], [], ['p1']), false)
})

Deno.test('a topic in several paths is allowed when ANY one is enrolled and accessible', () => {
  assertEquals(guestMayGenerate(true, true, ['p2'], ['p1', 'p2', 'p3'], ['p2']), true)
  // Enrolled in one, accessible another: no single path satisfies both.
  assertEquals(guestMayGenerate(true, true, ['p1'], ['p1', 'p2'], ['p2']), false)
})

type Result = { data: unknown; error: unknown }

function fakeDb(results: Record<string, Result>) {
  const calls: Array<[string, ...unknown[]]> = []
  return {
    calls,
    from(table: string) {
      calls.push(['from', table])
      const result = results[table] ?? { data: [], error: null }
      const chain: Record<string, unknown> = {}
      for (const m of ['select', 'eq', 'in']) {
        chain[m] = (...args: unknown[]) => (calls.push([`${table}.${m}`, ...args]), chain)
      }
      chain.then = (resolve: (r: Result) => unknown, reject: (e: unknown) => unknown) =>
        Promise.resolve(result).then(resolve, reject)
      return chain
    },
  }
}

Deno.test('loadGuestGenerationScope reads enrolments and accessible paths among the topic paths', async () => {
  const db = fakeDb({
    user_learning_path_progress: { data: [{ learning_path_id: 'p2' }], error: null },
    learning_paths: { data: [{ id: 'p2' }], error: null },
  })
  const scope = await loadGuestGenerationScope(db, 'u1', ['p1', 'p2'])
  assertEquals(scope, { enrolledPathIds: ['p2'], guestAccessiblePathIds: ['p2'] })
  assertEquals(db.calls.filter((c) => c[0].endsWith('.eq') || c[0].endsWith('.in')), [
    ['user_learning_path_progress.eq', 'user_id', 'u1'],
    ['user_learning_path_progress.in', 'learning_path_id', ['p1', 'p2']],
    ['learning_paths.in', 'id', ['p1', 'p2']],
    ['learning_paths.eq', 'guest_accessible', true],
  ])
})

Deno.test('loadGuestGenerationScope skips the queries for a topic in no path', async () => {
  const db = fakeDb({})
  assertEquals(await loadGuestGenerationScope(db, 'u1', []), { enrolledPathIds: [], guestAccessiblePathIds: [] })
  assertEquals(db.calls, [])
})

Deno.test('loadGuestGenerationScope fails closed with a retryable 503', async () => {
  for (const table of ['user_learning_path_progress', 'learning_paths']) {
    const db = fakeDb({ [table]: { data: null, error: { message: 'boom' } } })
    const err = await assertRejects(() => loadGuestGenerationScope(db, 'u1', ['p1']), AppError)
    assertEquals(err.code, 'SERVICE_UNAVAILABLE')
    assertEquals(err.statusCode, 503)
  }
})

Deno.test('assertGuestMayGenerate throws ACCOUNT_REQUIRED reason generate, without querying for typed studies', async () => {
  const db = fakeDb({})
  const err = await assertRejects(
    () => assertGuestMayGenerate(db, { isGuest: true, userId: 'u1', verifiedCatalogue: false, topicPathIds: ['p1'] }),
    AppError,
  )
  assertEquals(err.code, 'ACCOUNT_REQUIRED')
  assertEquals(err.statusCode, 403)
  assertEquals(err.details, { reason: 'generate' })
  assertEquals(db.calls, [])
})

Deno.test('assertGuestMayGenerate passes full accounts without querying and allowed guests', async () => {
  const none = fakeDb({})
  await assertGuestMayGenerate(none, { isGuest: false, userId: 'u1', verifiedCatalogue: false, topicPathIds: [] })
  assertEquals(none.calls, [])
  const db = fakeDb({
    user_learning_path_progress: { data: [{ learning_path_id: 'p1' }], error: null },
    learning_paths: { data: [{ id: 'p1' }], error: null },
  })
  await assertGuestMayGenerate(db, { isGuest: true, userId: 'u1', verifiedCatalogue: true, topicPathIds: ['p1'] })
})

Deno.test('assertGuestMayGenerate refuses a verified lesson of a path the guest may not study', async () => {
  const db = fakeDb({
    user_learning_path_progress: { data: [{ learning_path_id: 'p1' }], error: null },
    learning_paths: { data: [], error: null },
  })
  const err = await assertRejects(
    () => assertGuestMayGenerate(db, { isGuest: true, userId: 'u1', verifiedCatalogue: true, topicPathIds: ['p1'] }),
    AppError,
  )
  assertEquals(err.details, { reason: 'generate' })
})
