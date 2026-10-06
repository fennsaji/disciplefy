// Run with: deno test --allow-read _shared/auth/user-context.test.ts
import { assert, assertEquals, assertThrows } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  toUserContext,
  assertFullAccount,
  enforceFullAccount,
  isAnonymousAuthUser,
  ACCOUNT_ONLY_FUNCTIONS,
} from './user-context.ts'
import { AppError } from '../utils/error-handler.ts'

Deno.test('anonymous Supabase user becomes an authenticated guest with a userId', () => {
  const ctx = toUserContext({ id: 'u1', email: undefined, isAnonymous: true } as never)
  assertEquals(ctx, { type: 'authenticated', userId: 'u1', isGuest: true, email: undefined })
})

Deno.test('full user is not a guest', () => {
  const ctx = toUserContext({ id: 'u2', email: 'a@b.c', isAnonymous: false } as never)
  assertEquals(ctx.isGuest, false)
  assertEquals(ctx.userId, 'u2')
})

Deno.test('a guest never carries an email, even if one is present', () => {
  const ctx = toUserContext({ id: 'u3', email: 'x@y.z', isAnonymous: true } as never)
  assertEquals(ctx.email, undefined)
})

Deno.test('assertFullAccount rejects guests with ACCOUNT_REQUIRED', () => {
  const err = assertThrows(() => assertFullAccount({ type: 'authenticated', userId: 'u1', isGuest: true }))
  assertEquals((err as { code?: string }).code, 'ACCOUNT_REQUIRED')
  assertFullAccount({ type: 'authenticated', userId: 'u2', isGuest: false }) // no throw
})

Deno.test('assertFullAccount is a 403 AppError and rejects missing or legacy anonymous contexts', () => {
  const err = assertThrows(() => assertFullAccount({ type: 'authenticated', userId: 'u1', isGuest: true }))
  assert(err instanceof AppError)
  assertEquals((err as AppError).statusCode, 403)
  assertThrows(() => assertFullAccount(undefined))
  assertThrows(() => assertFullAccount({ type: 'anonymous', sessionId: 's1' }))
})

// Factory gate: what createFunction runs after parseUserContext.
Deno.test('enforceFullAccount: guest gets 403 ACCOUNT_REQUIRED on an account-only function', () => {
  const err = assertThrows(() =>
    enforceFullAccount(true, { type: 'authenticated', userId: 'u1', isGuest: true })
  )
  assertEquals((err as AppError).code, 'ACCOUNT_REQUIRED')
  assertEquals((err as AppError).statusCode, 403)
})

Deno.test('enforceFullAccount: guest passes on a function that does not require a full account', () => {
  enforceFullAccount(false, { type: 'authenticated', userId: 'u1', isGuest: true })
})

Deno.test('enforceFullAccount: full account passes', () => {
  enforceFullAccount(true, { type: 'authenticated', userId: 'u2', isGuest: false })
  // Internal caller / contexts built without the flag are full accounts.
  enforceFullAccount(true, { type: 'authenticated', userId: 'u2' })
})

Deno.test('enforceFullAccount: tokenless and legacy session callers are left to the handler', () => {
  // Public routes (e.g. fellowship-posts/share for link previews) are called with only
  // the anon key; the handler's own auth decides, exactly as before.
  enforceFullAccount(true, undefined)
  enforceFullAccount(true, { type: 'anonymous', sessionId: 's1' })
})

Deno.test('isAnonymousAuthUser reads the Supabase is_anonymous flag', () => {
  assertEquals(isAnonymousAuthUser({ is_anonymous: true }), true)
  assertEquals(isAnonymousAuthUser({ is_anonymous: false }), false)
  assertEquals(isAnonymousAuthUser({}), false)
})

// Static check: every account-only function is closed to guests.
const FUNCTIONS_DIR = new URL('../../', import.meta.url)
const FACTORY_CALL = /create(?:Simple|Authenticated)?Function\(\s*\w+\s*,\s*\{[^}]*requireFullAccount:\s*true/s
const RAW_GUARD = /isAnonymousAuthUser\(\s*user\s*\)/

Deno.test('every account-only function declares the full-account requirement', async () => {
  for (const name of ACCOUNT_ONLY_FUNCTIONS) {
    const source = await Deno.readTextFile(new URL(`${name}/index.ts`, FUNCTIONS_DIR))
    assert(
      FACTORY_CALL.test(source) || RAW_GUARD.test(source),
      `${name} must set requireFullAccount: true (or guard raw serve with isAnonymousAuthUser)`,
    )
  }
})

const GUEST_ALLOWED = [
  'study-generate', 'study-generate-v2', 'study-guides', 'learning-paths', 'daily-verse',
  'user-profile', 'topic-progress', 'mark-study-guide-complete', 'token-status', 'system-config',
  'continue-learning', 'get-active-challenges', 'add-memory-verse-from-daily', 'get-due-memory-verses',
]

Deno.test('guest-allowed functions do not require a full account', async () => {
  for (const name of GUEST_ALLOWED) {
    const source = await Deno.readTextFile(new URL(`${name}/index.ts`, FUNCTIONS_DIR))
    assert(!source.includes('requireFullAccount'), `${name} must stay open to guests`)
    assert(!RAW_GUARD.test(source), `${name} must stay open to guests`)
  }
})
