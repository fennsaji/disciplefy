// Run with: deno test --allow-env --allow-net _shared/auth/jwt-verifier.test.ts
import { assert, assertEquals, assertRejects } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import * as jose from 'npm:jose@5'
import { JwtVerificationError, JwtVerifier } from './jwt-verifier.ts'
import { AuthService } from '../services/auth-service.ts'

const ISS = 'http://127.0.0.1:54321/auth/v1'
const USER_ID = '351a3aa0-a905-4155-bef7-4d7a06e2e7f8'

const projectKey = await jose.generateKeyPair('ES256', { extractable: true })
const otherKey = await jose.generateKeyPair('ES256', { extractable: true })
const publicJwk = { ...(await jose.exportJWK(projectKey.publicKey)), kid: 'project-kid', alg: 'ES256', use: 'sig' }
const keys = jose.createLocalJWKSet({ keys: [publicJwk] })
const verifier = new JwtVerifier({ keys })

interface SignOpts {
  claims?: Record<string, unknown>
  key?: jose.KeyLike
  kid?: string
  exp?: number | string
}

function sign(opts: SignOpts = {}): Promise<string> {
  return new jose.SignJWT({
    role: 'authenticated',
    email: 'gen.check@local.test',
    is_anonymous: false,
    ...opts.claims,
  })
    .setProtectedHeader({ alg: 'ES256', kid: opts.kid ?? 'project-kid', typ: 'JWT' })
    .setIssuer((opts.claims?.iss as string) ?? ISS)
    .setSubject((opts.claims?.sub as string) ?? USER_ID)
    .setAudience((opts.claims?.aud as string) ?? 'authenticated')
    .setIssuedAt()
    .setExpirationTime(opts.exp ?? '1h')
    .sign(opts.key ?? projectKey.privateKey)
}

Deno.test('valid token verifies locally', async () => {
  const token = await sign()
  const identity = await verifier.verify(token)
  assertEquals(identity, {
    id: USER_ID,
    email: 'gen.check@local.test',
    isAnonymous: false,
    token,
    source: 'local',
  })
})

Deno.test('anonymous (is_anonymous) user keeps its id, drops email', async () => {
  const identity = await verifier.verify(await sign({ claims: { is_anonymous: true, email: '' } }))
  assertEquals(identity?.isAnonymous, true)
  assertEquals(identity?.id, USER_ID)
  assertEquals(identity?.email, undefined)
})

Deno.test('expired token is rejected', async () => {
  const token = await sign({ exp: Math.floor(Date.now() / 1000) - 10 })
  await assertRejects(() => verifier.verify(token), JwtVerificationError, 'expired')
})

Deno.test('token signed by a different key is rejected', async () => {
  const token = await sign({ key: otherKey.privateKey })
  await assertRejects(() => verifier.verify(token), JwtVerificationError)
})

Deno.test('tampered payload is rejected', async () => {
  const [h, , s] = (await sign()).split('.')
  const forged = jose.base64url.encode(JSON.stringify({
    sub: '00000000-0000-0000-0000-000000000001', role: 'authenticated', aud: 'authenticated',
    iss: ISS, exp: Math.floor(Date.now() / 1000) + 3600,
  }))
  await assertRejects(() => verifier.verify(`${h}.${forged}.${s}`), JwtVerificationError)
})

Deno.test('wrong audience is rejected', async () => {
  const token = await sign({ claims: { aud: 'other' } })
  await assertRejects(() => verifier.verify(token), JwtVerificationError)
})

Deno.test('non-authenticated role is rejected', async () => {
  const token = await sign({ claims: { role: 'service_role' } })
  await assertRejects(() => verifier.verify(token), JwtVerificationError, 'role')
})

Deno.test('foreign issuer is rejected; exact issuer enforced when configured', async () => {
  const foreign = await sign({ claims: { iss: 'https://evil.example' } })
  await assertRejects(() => verifier.verify(foreign), JwtVerificationError, 'issuer')
  const strict = new JwtVerifier({ keys, issuer: 'https://ref.supabase.co/auth/v1' })
  const token = await sign()
  await assertRejects(() => strict.verify(token), JwtVerificationError)
})

Deno.test('non-uuid subject is rejected', async () => {
  const token = await sign({ claims: { sub: 'not-a-uuid' } })
  await assertRejects(() => verifier.verify(token), JwtVerificationError, 'subject')
})

Deno.test('malformed token is rejected', async () => {
  await assertRejects(() => verifier.verify('not-a-jwt'), JwtVerificationError)
  await assertRejects(() => verifier.verify(''), JwtVerificationError)
})

Deno.test('legacy HS256 token (e.g. anon key) is left to the Auth server', async () => {
  const anonKey = await new jose.SignJWT({ role: 'anon' })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuer('supabase-demo')
    .setExpirationTime('1h')
    .sign(new TextEncoder().encode('super-secret-jwt-token-with-at-least-32-characters-long'))
  assertEquals(await verifier.verify(anonKey), null)
})

Deno.test('alg "none" is never accepted', async () => {
  const unsigned = new jose.UnsecuredJWT({ sub: USER_ID, role: 'authenticated', aud: 'authenticated', iss: ISS })
    .setExpirationTime('1h').encode()
  assertEquals(await verifier.verify(unsigned), null) // not asymmetric -> Auth server, which rejects it
})

Deno.test('unknown kid (key rotation) is left to the Auth server', async () => {
  const token = await sign({ key: otherKey.privateKey, kid: 'new-kid' })
  assertEquals(await verifier.verify(token), null)
})

Deno.test('no key resolver -> Auth server', async () => {
  assertEquals(await new JwtVerifier({ keys: null }).verify(await sign()), null)
})

// ---------------------------------------------------------------------------
// AuthService: factory-primed identity + per-request memo
// ---------------------------------------------------------------------------

function fakeServiceClient(counts: Record<string, number>) {
  const bump = (k: string) => (counts[k] = (counts[k] ?? 0) + 1)
  return {
    rpc: (_fn: string, _args: unknown) => {
      bump('rpc')
      return Promise.resolve({ data: 'plus', error: null })
    },
    from: (_t: string) => ({
      select: () => ({
        eq: () => ({
          single: () => {
            bump('profile')
            return Promise.resolve({ data: { id: USER_ID, is_admin: false }, error: null })
          },
        }),
      }),
    }),
    auth: {
      getUser: (_t: string) => {
        bump('getUser')
        return Promise.resolve({ data: { user: { id: 'network-user', email: 'n@x', is_anonymous: false } }, error: null })
      },
    },
  }
}

function primedRequest(service: AuthService, token: string) {
  const req = new Request('http://localhost/fn', { headers: { Authorization: `Bearer ${token}` } })
  service.primeVerifiedIdentity(req, {
    id: USER_ID, email: 'gen.check@local.test', isAnonymous: false, token, source: 'local',
  })
  return req
}

Deno.test('getUserPlan is memoised per request and skips GoTrue + profile read', async () => {
  const counts: Record<string, number> = {}
  const service = new AuthService('http://x', 'anon', fakeServiceClient(counts) as never)
  const req = primedRequest(service, 'tok')
  assertEquals(await service.getUserPlan(req), 'plus')
  assertEquals(await service.getUserPlan(req), 'plus')
  assertEquals(counts, { rpc: 1 })

  // A different request is not shared.
  const other = primedRequest(service, 'tok')
  await service.getUserPlan(other)
  assertEquals(counts.rpc, 2)
})

Deno.test('getUserContext uses primed identity and memoises the profile read', async () => {
  const counts: Record<string, number> = {}
  const service = new AuthService('http://x', 'anon', fakeServiceClient(counts) as never)
  const req = primedRequest(service, 'tok')
  const a = await service.getUserContext(req)
  const b = await service.getUserContext(req)
  assertEquals(a, {
    type: 'authenticated', userId: USER_ID, sessionId: undefined, userType: 'user', email: 'gen.check@local.test',
  })
  assert(a === b)
  assertEquals(counts, { profile: 1 })
})

Deno.test('getUserFromToken reuses primed identity only for the same token', async () => {
  const counts: Record<string, number> = {}
  const service = new AuthService('http://x', 'anon', fakeServiceClient(counts) as never)
  const req = primedRequest(service, 'tok')
  assertEquals((await service.getUserFromToken(req, 'tok')).data.user?.id, USER_ID)
  assertEquals(counts.getUser, undefined)
  // Different token than the one verified -> ask the Auth server.
  assertEquals((await service.getUserFromToken(req, 'other')).data.user?.id, 'network-user')
  assertEquals(counts.getUser, 1)
  // Unprimed request -> Auth server.
  const plain = new Request('http://localhost/fn', { headers: { Authorization: 'Bearer tok' } })
  await service.getUserFromToken(plain, 'tok')
  assertEquals(counts.getUser, 2)
})
