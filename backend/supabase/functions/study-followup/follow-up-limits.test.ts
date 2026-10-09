import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { getFollowUpLimit } from './follow-up-limits.ts'

Deno.test('follow-up limits rise with each plan', () => {
  assertEquals(getFollowUpLimit('standard'), 10)
  assertEquals(getFollowUpLimit('plus'), 15)
  assertEquals(getFollowUpLimit('premium'), 20)
})

Deno.test('Plus no longer falls back to the free limit', () => {
  assertEquals(getFollowUpLimit('plus') > getFollowUpLimit('standard'), true)
})

Deno.test('unknown plans get the free limit', () => {
  assertEquals(getFollowUpLimit('weird'), 3)
  assertEquals(getFollowUpLimit('free'), 3)
})
