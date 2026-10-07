import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  GUEST_TOKEN_HEADER,
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
