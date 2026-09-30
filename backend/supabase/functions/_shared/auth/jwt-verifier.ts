/**
 * Local verification of Supabase Auth access tokens.
 *
 * Verifies user JWTs against the project's asymmetric signing keys (JWKS),
 * so the common request path does not call GoTrue `/auth/v1/user`.
 * Follows https://supabase.com/docs/guides/auth/jwts#verifying-a-jwt-from-supabase
 *
 * Outcomes of `verify(token)`:
 * - `VerifiedIdentity`  signature, `exp`, `aud`, `role`, `iss` and `sub` all valid.
 * - `null`              cannot be decided locally (legacy HS256 token, no JWKS,
 *                       unknown `kid` after a key rotation, JWKS fetch failure).
 *                       The caller must verify with the Auth server instead.
 * - throws `JwtVerificationError`  the token is definitely invalid
 *                       (malformed, expired, bad signature, wrong claims).
 *
 * Limitation: a locally verified token stays valid until `exp` even if its
 * session was revoked (logout, ban, user deletion). Endpoints that must see
 * revocation opt into Auth-server verification (`verifyWithAuthServer`).
 */

import * as jose from 'npm:jose@5'

export interface VerifiedIdentity {
  /** auth.users id (`sub`) */
  readonly id: string
  readonly email?: string
  readonly isAnonymous: boolean
  /** Raw access token the identity was derived from */
  readonly token: string
  /** How the token was verified */
  readonly source: 'local' | 'auth-server'
}

export class JwtVerificationError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'JwtVerificationError'
  }
}

export type JwtKeyResolver = jose.JWTVerifyGetKey

export interface JwtVerifierOptions {
  /** Key resolver (remote or local JWKS). `null` disables local verification. */
  readonly keys: JwtKeyResolver | null
  /** Exact expected issuer. When omitted, `iss` must end with `/auth/v1`. */
  readonly issuer?: string
}

/** Algorithms Supabase uses for asymmetric signing keys. HS256 is never verified locally. */
const ASYMMETRIC_ALGORITHMS = ['ES256', 'RS256', 'EdDSA']
const AUDIENCE = 'authenticated'
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** JOSE error codes that mean "could not check", not "invalid". */
const UNDECIDABLE_CODES = new Set([
  'ERR_JWKS_NO_MATCHING_KEY',
  'ERR_JWKS_TIMEOUT',
  'ERR_JWKS_INVALID',
  'ERR_JWKS_MULTIPLE_MATCHING_KEYS',
  // jose uses the generic code for a non-200 JWKS response
  'ERR_JOSE_GENERIC',
])

export class JwtVerifier {
  constructor(private readonly options: JwtVerifierOptions) {}

  async verify(token: string): Promise<VerifiedIdentity | null> {
    let header: jose.ProtectedHeaderParameters
    try {
      header = jose.decodeProtectedHeader(token)
    } catch {
      throw new JwtVerificationError('malformed JWT')
    }

    if (!header.alg || !ASYMMETRIC_ALGORITHMS.includes(header.alg)) return null
    if (!this.options.keys) return null

    let payload: jose.JWTPayload
    try {
      const result = await jose.jwtVerify(token, this.options.keys, {
        algorithms: ASYMMETRIC_ALGORITHMS,
        audience: AUDIENCE,
        issuer: this.options.issuer,
        requiredClaims: ['exp', 'sub', 'iss', 'role'],
      })
      payload = result.payload
    } catch (error) {
      const code = (error as { code?: string })?.code
      if (code && UNDECIDABLE_CODES.has(code)) return null
      if (error instanceof jose.errors.JOSEError) {
        throw new JwtVerificationError(code === 'ERR_JWT_EXPIRED' ? 'JWT has expired' : 'invalid JWT')
      }
      // Key fetch failure (e.g. fetch rejected): let the Auth server decide.
      return null
    }

    if (payload.role !== 'authenticated') {
      throw new JwtVerificationError('invalid JWT role claim')
    }
    if (!this.options.issuer && !(typeof payload.iss === 'string' && payload.iss.endsWith('/auth/v1'))) {
      throw new JwtVerificationError('invalid JWT issuer claim')
    }
    if (typeof payload.sub !== 'string' || !UUID_PATTERN.test(payload.sub)) {
      throw new JwtVerificationError('invalid JWT subject claim')
    }

    const isAnonymous = payload.is_anonymous === true
    const email = typeof payload.email === 'string' ? payload.email : undefined
    return {
      id: payload.sub,
      email: isAnonymous ? undefined : email,
      isAnonymous,
      token,
      source: 'local',
    }
  }
}

/**
 * Builds the key resolver for this project.
 * Prefers the platform-provided `SUPABASE_JWKS` env (no network at all); otherwise
 * fetches `/auth/v1/.well-known/jwks.json`, cached in memory by jose
 * (10 min max age, matching the Supabase client library).
 */
export function createProjectKeyResolver(supabaseUrl: string): JwtKeyResolver | null {
  const inline = Deno.env.get('SUPABASE_JWKS')
  if (inline) {
    try {
      const jwks = JSON.parse(inline)
      if (Array.isArray(jwks?.keys) && jwks.keys.length > 0) {
        return jose.createLocalJWKSet(jwks)
      }
    } catch {
      console.warn('[AUTH] SUPABASE_JWKS is not valid JSON; using the JWKS endpoint')
    }
  }
  if (!supabaseUrl) return null
  return jose.createRemoteJWKSet(new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`), {
    timeoutDuration: 3000,
    cooldownDuration: 30_000,
    cacheMaxAge: 600_000,
  })
}

let projectVerifier: JwtVerifier | null = null

/**
 * Worker-wide verifier. `AUTH_LOCAL_JWT_VERIFY=false` turns local verification
 * off (every token then goes to the Auth server, the previous behaviour).
 */
export function getProjectJwtVerifier(supabaseUrl: string): JwtVerifier {
  if (!projectVerifier) {
    const enabled = (Deno.env.get('AUTH_LOCAL_JWT_VERIFY') ?? 'true').toLowerCase() !== 'false'
    projectVerifier = new JwtVerifier({
      keys: enabled ? createProjectKeyResolver(supabaseUrl) : null,
      issuer: Deno.env.get('SUPABASE_JWT_ISSUER') || undefined,
    })
  }
  return projectVerifier
}

export interface TokenUser {
  readonly id: string
  readonly email?: string
  readonly is_anonymous: boolean
}

/**
 * For functions outside the function factory: verifies a user access token
 * locally when possible, otherwise via `fromAuthServer` (the previous
 * `auth.getUser` call). Returns null for an invalid token.
 */
export async function verifyUserToken(
  token: string,
  supabaseUrl: string,
  fromAuthServer: () => Promise<TokenUser | null>
): Promise<TokenUser | null> {
  try {
    const identity = await getProjectJwtVerifier(supabaseUrl).verify(token)
    if (identity) {
      return { id: identity.id, email: identity.email, is_anonymous: identity.isAnonymous }
    }
  } catch (error) {
    if (error instanceof JwtVerificationError) return null
    throw error
  }
  return await fromAuthServer()
}
