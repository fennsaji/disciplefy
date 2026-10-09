// Run with: deno test fellowship-push-reach.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { pushOutcomesByUser, reachableFellowshipMembers } from './discipler-service.ts'

/**
 * Comment, reaction and Discipler-reply pushes are addressed to people found
 * through old rows (past commenters, post authors, askers). Only muting was
 * filtered, so members who had left or been removed were still notified.
 */
Deno.test('fellowship pushes reach only active, unmuted members', () => {
  const rows = [
    { user_id: 'active', is_active: true, notifications_muted: false },
    { user_id: 'left', is_active: false, notifications_muted: false },
    { user_id: 'muted', is_active: true, notifications_muted: true },
    { user_id: 'null-mute', is_active: true, notifications_muted: null },
  ]
  assertEquals(
    reachableFellowshipMembers(['active', 'left', 'muted', 'removed', 'null-mute'], rows),
    ['active', 'null-mute'],
  )
})

Deno.test('no membership rows means no recipients', () => {
  assertEquals(reachableFellowshipMembers(['a', 'b'], []), [])
})

/**
 * deliverOrQueue logged every immediate recipient as 'sent' whether or not
 * FCM accepted the push. The outcome is now per user, from the token results.
 */
Deno.test('push outcomes come from FCM results, per user', () => {
  const out = pushOutcomesByUser(
    ['a', 'b', 'c', 'd'],
    [
      { user_id: 'a', fcm_token: 'a1' },
      { user_id: 'b', fcm_token: 'b1' },
      { user_id: 'b', fcm_token: 'b2' },
      { user_id: 'c', fcm_token: 'c1' },
    ],
    [{ success: true }, { success: false }, { success: true }, { success: false }],
  )
  assertEquals(Object.fromEntries(out), { a: 'sent', b: 'sent', c: 'failed', d: 'no_device' })
})
