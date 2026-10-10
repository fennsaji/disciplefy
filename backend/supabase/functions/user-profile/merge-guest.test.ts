import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  GUEST_TOKEN_HEADER,
  isGuestNotAnonymousError,
  mergeGuestGrowthGoal,
  mergeGuestNewForYou,
  normalizeMergeCounts,
  readGuestToken,
  validateMergeRequest,
} from './merge-guest.ts'

Deno.test('merge requires a different, anonymous guest', () => {
  assertEquals(validateMergeRequest('u', null), 'GUEST_TOKEN_INVALID')
  assertEquals(validateMergeRequest('u', { id: 'g', isAnonymous: false }), 'GUEST_TOKEN_INVALID')
  assertEquals(validateMergeRequest('u', { id: 'u', isAnonymous: true }), 'GUEST_TOKEN_INVALID')
  assertEquals(validateMergeRequest('u', { id: 'g', isAnonymous: true }), null)
})

Deno.test('merge rejects an empty caller id', () => {
  assertEquals(validateMergeRequest('', { id: 'g', isAnonymous: true }), 'GUEST_TOKEN_INVALID')
})

function req(token?: string): Request {
  const headers = new Headers()
  if (token !== undefined) headers.set(GUEST_TOKEN_HEADER, token)
  return new Request('http://localhost/user-profile?action=merge_guest', { method: 'POST', headers })
}

Deno.test('readGuestToken returns the trimmed header value', () => {
  assertEquals(readGuestToken(req('  a.b.c  ')), 'a.b.c')
  assertEquals(readGuestToken(req('Bearer a.b.c')), 'a.b.c')
})

Deno.test('readGuestToken rejects missing, empty, oversized or non-JWT values', () => {
  assertEquals(readGuestToken(req()), null)
  assertEquals(readGuestToken(req('   ')), null)
  assertEquals(readGuestToken(req('not-a-jwt')), null)
  assertEquals(readGuestToken(req('a.b.c d')), null)
  assertEquals(readGuestToken(req('a.' + 'b'.repeat(5000) + '.c')), null)
})

Deno.test('normalizeMergeCounts keeps the four counts as non-negative integers', () => {
  assertEquals(
    normalizeMergeCounts({ topics: 2, paths: 1, guides: 3, verses: 0, achievements: 4 }),
    { topics: 2, paths: 1, guides: 3, verses: 0 },
  )
  assertEquals(normalizeMergeCounts(null), { topics: 0, paths: 0, guides: 0, verses: 0 })
  assertEquals(
    normalizeMergeCounts({ topics: '2', paths: -1, guides: 1.5 }),
    { topics: 0, paths: 0, guides: 0, verses: 0 },
  )
})

Deno.test('only the not_anonymous RPC error maps to an invalid guest token', () => {
  assertEquals(isGuestNotAnonymousError({ code: 'P0001', message: 'merge_guest:not_anonymous' }), true)
  assertEquals(isGuestNotAnonymousError({ code: 'P0001', message: 'merge_guest:target_not_full' }), false)
  assertEquals(isGuestNotAnonymousError({ code: 'P0001', message: 'merge_guest:invalid_pair' }), false)
  assertEquals(isGuestNotAnonymousError({ code: '22023', message: 'merge_guest:not_anonymous' }), false)
  assertEquals(isGuestNotAnonymousError({ code: '23505', message: 'duplicate key' }), false)
  assertEquals(isGuestNotAnonymousError(null), false)
})

Deno.test('mergeGuestNewForYou calls the merge function with guest and user', async () => {
  const calls: Array<[string, Record<string, unknown>]> = []
  const ok = await mergeGuestNewForYou(async (fn, args) => {
    calls.push([fn, args])
    return { error: null }
  }, 'g', 'u')
  assertEquals(ok, true)
  assertEquals(calls, [['merge_guest_new_for_you', { p_guest: 'g', p_user: 'u' }]])
})

Deno.test('mergeGuestNewForYou never fails the merge', async () => {
  assertEquals(await mergeGuestNewForYou(async () => ({ error: { code: '42883' } }), 'g', 'u'), false)
  assertEquals(await mergeGuestNewForYou(() => Promise.reject(new Error('down')), 'g', 'u'), false)
})

Deno.test('mergeGuestGrowthGoal carries the guest goal and never fails the merge', async () => {
  const calls: Array<[string, Record<string, unknown>]> = []
  const ok = await mergeGuestGrowthGoal(async (fn, args) => {
    calls.push([fn, args])
    return { error: null }
  }, 'g', 'u')
  assertEquals(ok, true)
  assertEquals(calls, [['merge_guest_growth_goal', { p_guest: 'g', p_user: 'u' }]])
  assertEquals(await mergeGuestGrowthGoal(async () => ({ error: { code: '42883' } }), 'g', 'u'), false)
  assertEquals(await mergeGuestGrowthGoal(() => Promise.reject(new Error('down')), 'g', 'u'), false)
})
