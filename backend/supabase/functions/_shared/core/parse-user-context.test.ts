// Run with: deno test --allow-env --allow-net --allow-read _shared/core/parse-user-context.test.ts
import { assertEquals, assertRejects } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import * as jose from 'npm:jose@5'

const USER_ID = '351a3aa0-a905-4155-bef7-4d7a06e2e7f8'
const ANON_KEY = 'test-anon-key'
const key = await jose.generateKeyPair('ES256', { extractable: true })
const jwk = { ...(await jose.exportJWK(key.publicKey)), kid: 'k1', alg: 'ES256' }

Deno.env.set('SUPABASE_URL', 'http://127.0.0.1:1')
Deno.env.set('SUPABASE_ANON_KEY', ANON_KEY)
Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-service-key')
Deno.env.set('SUPABASE_JWKS', JSON.stringify({ keys: [jwk] }))

const { parseUserContext } = await import('./function-factory.ts')

const primed: unknown[] = []
const services = { authService: { primeVerifiedIdentity: (_r: Request, id: unknown) => primed.push(id) } } as never

const sign = (exp: string | number = '1h', claims: Record<string, unknown> = {}) =>
  new jose.SignJWT({ role: 'authenticated', email: 'a@b.c', is_anonymous: false, ...claims })
    .setProtectedHeader({ alg: 'ES256', kid: 'k1' })
    .setIssuer('http://127.0.0.1:54321/auth/v1').setSubject(USER_ID).setAudience('authenticated')
    .setExpirationTime(exp).sign(key.privateKey)

const req = (auth?: string, headers: Record<string, string> = {}) =>
  new Request('http://localhost/fn', { headers: { ...(auth ? { Authorization: auth } : {}), ...headers } })

Deno.test('missing header throws', async () => {
  await assertRejects(() => parseUserContext(req(), services), Error, 'Missing authorization header')
})

Deno.test('anon key with session id -> anonymous guest; without -> throws', async () => {
  assertEquals(await parseUserContext(req(`Bearer ${ANON_KEY}`, { 'x-session-id': 's1' }), services), {
    type: 'anonymous', userId: undefined, sessionId: 's1',
  })
  await assertRejects(() => parseUserContext(req(`Bearer ${ANON_KEY}`), services), Error, 'Guest user')
})

Deno.test('valid user JWT verified locally, context + primed identity', async () => {
  const token = await sign()
  const r = req(`Bearer ${token}`)
  assertEquals(await parseUserContext(r, services), {
    type: 'authenticated', userId: USER_ID, sessionId: undefined, email: 'a@b.c',
  })
  assertEquals((primed.at(-1) as { token: string; source: string }).source, 'local')
})

Deno.test('is_anonymous user -> anonymous context with sessionId = user id', async () => {
  const token = await sign('1h', { is_anonymous: true })
  assertEquals(await parseUserContext(req(`Bearer ${token}`), services), {
    type: 'anonymous', userId: undefined, sessionId: USER_ID, email: undefined,
  })
})

Deno.test('expired / tampered JWT -> Authentication failed; guest fallback only when allowed', async () => {
  const expired = await sign(Math.floor(Date.now() / 1000) - 5)
  await assertRejects(() => parseUserContext(req(`Bearer ${expired}`), services), Error, 'Authentication failed')
  const [h, p, s] = (await sign()).split('.')
  const tampered = `${h}.${p}.${s.slice(0, -4)}AAAA`
  await assertRejects(() => parseUserContext(req(`Bearer ${tampered}`), services), Error, 'Authentication failed')
  assertEquals(
    await parseUserContext(req(`Bearer ${expired}`, { 'x-session-id': 's2' }), services, true),
    { type: 'anonymous', userId: undefined, sessionId: 's2' },
  )
})
