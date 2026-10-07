import { assertEquals, assertRejects, assertThrows } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import {
  assertGuestMayEnroll,
  canGuestEnroll,
  guestEnrollDenial,
  loadGuestAccessiblePathIds,
  loadPathGuestAccessible,
  parseEnrollTarget,
  resolvePathIdBySlug,
} from './guest-rules.ts'

Deno.test('guest can enrol the first accessible path and re-enrol it, not a second', () => {
  assertEquals(canGuestEnroll([], 'p1', true), true)
  assertEquals(canGuestEnroll(['p1'], 'p1', true), true)
  assertEquals(canGuestEnroll(['p1'], 'p2', true), false)
})

Deno.test('guest can never enrol a path that is not guest-accessible', () => {
  assertEquals(canGuestEnroll([], 'p1', false), false)
  assertEquals(canGuestEnroll(['p1'], 'p1', false), false)
  assertEquals(canGuestEnroll(['p1'], 'p2', false), false)
})

Deno.test('guestEnrollDenial checks accessibility first, then the one-path rule', () => {
  assertEquals(guestEnrollDenial([], 'p1', true), null)
  assertEquals(guestEnrollDenial(['p1'], 'p1', true), null)
  assertEquals(guestEnrollDenial(['p1'], 'p2', true), 'second_path')
  assertEquals(guestEnrollDenial([], 'p1', false), 'other_path')
  assertEquals(guestEnrollDenial(['p1'], 'p2', false), 'other_path')
  assertEquals(guestEnrollDenial(['p1'], 'p1', false), 'other_path')
})

Deno.test('assertGuestMayEnroll throws ACCOUNT_REQUIRED with reason other_path or second_path', () => {
  assertGuestMayEnroll([], 'p1', true)
  assertGuestMayEnroll(['p1'], 'p1', true)
  const second = assertThrows(() => assertGuestMayEnroll(['p1'], 'p2', true), AppError)
  assertEquals(second.code, 'ACCOUNT_REQUIRED')
  assertEquals(second.statusCode, 403)
  assertEquals(second.details, { reason: 'second_path' })
  const other = assertThrows(() => assertGuestMayEnroll([], 'p3', false), AppError)
  assertEquals(other.code, 'ACCOUNT_REQUIRED')
  assertEquals(other.statusCode, 403)
  assertEquals(other.details, { reason: 'other_path' })
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

Deno.test('loadPathGuestAccessible reads the flag fresh and maps errors', async () => {
  const open = fakeClient({ guest_accessible: true })
  assertEquals(await loadPathGuestAccessible(open, 'p1'), true)
  assertEquals(open.calls, [
    ['from', 'learning_paths'],
    ['select', 'guest_accessible'],
    ['eq:id', 'p1'],
    ['eq:is_active', true],
  ])
  assertEquals(await loadPathGuestAccessible(fakeClient({ guest_accessible: false }), 'p1'), false)
  assertEquals(await loadPathGuestAccessible(fakeClient({ guest_accessible: null }), 'p1'), false)
  const missing = await assertRejects(() => loadPathGuestAccessible(fakeClient(null), 'p1'), AppError)
  assertEquals(missing.code, 'NOT_FOUND')
  const failed = await assertRejects(
    () => loadPathGuestAccessible(fakeClient(null, { message: 'boom' }), 'p1'),
    AppError,
  )
  assertEquals(failed.code, 'DATABASE_ERROR')
})

function fakeListClient(rows: unknown, error: unknown = null) {
  const calls: Array<[string, unknown]> = []
  const builder = {
    select: (c: string) => (calls.push(['select', c]), builder),
    eq: (c: string, v: unknown) => {
      calls.push([`eq:${c}`, v])
      return Promise.resolve({ data: rows, error })
    },
  }
  return { calls, from: (t: string) => (calls.push(['from', t]), builder) }
}

Deno.test('loadGuestAccessiblePathIds returns the flagged ids, null on error', async () => {
  const client = fakeListClient([{ id: 'a' }, { id: 'b' }])
  assertEquals(await loadGuestAccessiblePathIds(client), new Set(['a', 'b']))
  assertEquals(client.calls, [
    ['from', 'learning_paths'],
    ['select', 'id'],
    ['eq:guest_accessible', true],
  ])
  assertEquals(await loadGuestAccessiblePathIds(fakeListClient(null, { message: 'x' })), null)
})
