import { assertEquals, assertRejects, assertThrows } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import {
  assertGuestMayEnroll,
  canGuestEnroll,
  parseEnrollTarget,
  resolvePathIdBySlug,
} from './guest-rules.ts'

Deno.test('guest can enrol the first path and re-enrol it, not a second', () => {
  assertEquals(canGuestEnroll([], 'p1'), true)
  assertEquals(canGuestEnroll(['p1'], 'p1'), true)
  assertEquals(canGuestEnroll(['p1'], 'p2'), false)
})

Deno.test('assertGuestMayEnroll throws ACCOUNT_REQUIRED with reason second_path', () => {
  assertGuestMayEnroll([], 'p1')
  assertGuestMayEnroll(['p1'], 'p1')
  const err = assertThrows(() => assertGuestMayEnroll(['p1'], 'p2'), AppError)
  assertEquals(err.code, 'ACCOUNT_REQUIRED')
  assertEquals(err.statusCode, 403)
  assertEquals(err.details, { reason: 'second_path' })
})

Deno.test('parseEnrollTarget prefers pathId, accepts slug, rejects neither or a bad slug', () => {
  assertEquals(parseEnrollTarget({ pathId: 'abc' }), { pathId: 'abc' })
  assertEquals(parseEnrollTarget({ pathId: 'abc', slug: 'x' }), { pathId: 'abc' })
  assertEquals(parseEnrollTarget({ slug: 'rooted-in-christ' }), { slug: 'rooted-in-christ' })
  assertEquals(parseEnrollTarget({ slug: '  Rooted-In-Christ ' }), { slug: 'rooted-in-christ' })
  assertEquals(parseEnrollTarget(null, 'q1'), { pathId: 'q1' })
  for (const bad of [{}, null, { slug: '' }, { slug: 'a b' }, { slug: 'x'.repeat(101) }, { slug: 5 }]) {
    const err = assertThrows(() => parseEnrollTarget(bad), AppError)
    assertEquals(err.code, 'VALIDATION_ERROR')
  }
})

function fakeClient(row: unknown, error: unknown = null) {
  const calls: Array<[string, unknown]> = []
  const builder = {
    select: (c: string) => (calls.push(['select', c]), builder),
    eq: (c: string, v: unknown) => (calls.push([`eq:${c}`, v]), builder),
    maybeSingle: () => Promise.resolve({ data: row, error }),
  }
  return {
    calls,
    from: (t: string) => (calls.push(['from', t]), builder),
  }
}

Deno.test('resolvePathIdBySlug looks up an active path by slug', async () => {
  const client = fakeClient({ id: 'path-1' })
  assertEquals(await resolvePathIdBySlug(client, 'rooted-in-christ'), 'path-1')
  assertEquals(client.calls, [
    ['from', 'learning_paths'],
    ['select', 'id'],
    ['eq:slug', 'rooted-in-christ'],
    ['eq:is_active', true],
  ])
})

Deno.test('resolvePathIdBySlug maps a missing path to NOT_FOUND and a query error to DATABASE_ERROR', async () => {
  const missing = await assertRejects(() => resolvePathIdBySlug(fakeClient(null), 'nope'), AppError)
  assertEquals(missing.code, 'NOT_FOUND')
  assertEquals(missing.statusCode, 404)
  const failed = await assertRejects(
    () => resolvePathIdBySlug(fakeClient(null, { message: 'boom' }), 'x'),
    AppError,
  )
  assertEquals(failed.code, 'DATABASE_ERROR')
})
