/**
 * Apple App Store Transaction Validation Service (StoreKit 2 / App Store Server API)
 *
 * The app sends the StoreKit 2 signed transaction (JWSTransaction) obtained from
 * `PurchaseDetails.verificationData.serverVerificationData`. We decode (not verify)
 * just its `transactionId`, then confirm the transaction directly with Apple via the
 * App Store Server API's `getTransactionInfo` endpoint — an authenticated HTTPS call
 * signed with our own In-App Purchase API key. Apple's response is trusted because it
 * arrived over TLS in reply to our own authenticated request, so no local certificate
 * chain verification is needed.
 *
 * Local signature/chain verification (via the official `@apple/app-store-server-library`,
 * `SignedDataVerifier`) was tried first but doesn't work here: it calls Node's
 * `crypto.X509Certificate.prototype.verify()`, which Deno's Node-compat layer does not
 * implement, on every code path regardless of `enableOnlineChecks`.
 *
 * The same library's `AppStoreServerAPIClient` (for calling this API) was tried next,
 * but it signs its bearer JWT via the `jsonwebtoken` npm package, which rejected our
 * ES256 EC private key with `"alg" parameter "ES256" requires curve "prime256v1"` —
 * Deno's Node-compat `crypto.createPrivateKey()` apparently reports the P-256 curve
 * under a different name than `jsonwebtoken` expects, so its strict curve-name check
 * fails even though the key itself is a valid P-256 key.
 *
 * Both failures are Deno Node-compat gaps in the *library's* internals, not in the
 * Apple API itself — so this signs the bearer JWT by hand using Deno's native Web
 * Crypto (`crypto.subtle`), which is a first-class Deno API (not a Node shim) and
 * makes the plain `fetch()` call directly, bypassing the npm library entirely.
 *
 * Docs: https://developer.apple.com/documentation/appstoreserverapi/get_transaction_info
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getIAPConfig } from './iap-config-service.ts'

type AppleEnvironment = 'sandbox' | 'production'

// Canonical domains since May 2026 (the older *.itunes.apple.com hosts still work
// but are legacy — see the App Store Server API changelog).
const API_BASE_URL: Record<AppleEnvironment, string> = {
  production: 'https://api.storekit.apple.com',
  sandbox: 'https://api.storekit-sandbox.apple.com',
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = ''
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

/** Import a PKCS8 PEM (Apple's downloaded .p8 file contents) as a Web Crypto P-256
 * signing key. */
async function importApplePrivateKey(pem: string): Promise<CryptoKey> {
  const der = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '')
  const binary = atob(der)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return await crypto.subtle.importKey(
    'pkcs8',
    bytes,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  )
}

/** Build and sign the ES256 bearer JWT the App Store Server API requires, per
 * https://developer.apple.com/documentation/appstoreserverapi/generating_tokens_for_api_requests */
async function createAppStoreServerAPIToken(
  issuerId: string,
  keyId: string,
  bundleId: string,
  privateKey: CryptoKey
): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000)
  const header = { alg: 'ES256', kid: keyId, typ: 'JWT' }
  const payload = {
    iss: issuerId,
    iat: nowSeconds,
    exp: nowSeconds + 5 * 60,
    aud: 'appstoreconnect-v1',
    bid: bundleId,
  }
  const encoder = new TextEncoder()
  const signingInput =
    base64UrlEncode(encoder.encode(JSON.stringify(header))) +
    '.' +
    base64UrlEncode(encoder.encode(JSON.stringify(payload)))
  // Web Crypto's ECDSA sign() output is the raw (r || s) format JWS/ES256 expects
  // directly — no DER-to-raw conversion needed (unlike Node's crypto.sign()).
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    privateKey,
    encoder.encode(signingInput)
  )
  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`
}

export interface AppleReceiptData {
  receiptData: string  // StoreKit 2 JWSTransaction (compact JWS) from the client
}

export interface AppleValidationResult {
  isValid: boolean
  transactionId: string
  originalTransactionId: string
  purchaseDate: Date
  expiryDate?: Date
  isTrial: boolean
  isIntroOffer: boolean
  autoRenewing: boolean
  validationResponse: any
  validatedProductId?: string  // store-confirmed product ID from the signed transaction
  error?: string
}

function failure(error: string, validationResponse: any = null): AppleValidationResult {
  return {
    isValid: false,
    transactionId: '',
    originalTransactionId: '',
    purchaseDate: new Date(),
    isTrial: false,
    isIntroOffer: false,
    autoRenewing: false,
    validationResponse,
    error,
  }
}

/** Decode (NOT verify) a compact JWS's payload segment. Only safe to use on a JWS
 * whose contents you don't yet trust for authorization — here, just to pull the
 * transactionId out of the client-submitted JWS before confirming it with Apple. */
function decodeJWSPayload(jws: string): any {
  const parts = jws.split('.')
  if (parts.length !== 3) {
    throw new Error('Malformed JWS (expected 3 dot-separated segments)')
  }
  const base64Url = parts[1]
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/')
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4)
  const json = atob(padded)
  return JSON.parse(json)
}

function describeError(e: unknown): string {
  return e instanceof Error ? `${e.name}: ${e.message || '(empty message)'}` : String(e)
}

/**
 * Validate an Apple StoreKit 2 signed transaction by confirming it with Apple's
 * App Store Server API.
 *
 * @param receipt.receiptData - the compact JWSTransaction string from the client
 * @param environment - resolved environment; if the transaction actually belongs to
 *   the other environment (e.g. a TestFlight/debug build produces Sandbox
 *   transactions even when the backend runs in production), the lookup is retried
 *   against the other environment.
 */
export async function validateAppleReceipt(
  supabase: SupabaseClient,
  receipt: AppleReceiptData,
  environment: 'sandbox' | 'production'
): Promise<AppleValidationResult> {
  console.log('[APPLE] Confirming StoreKit 2 transaction via App Store Server API for environment:', environment)

  try {
    const config = await getIAPConfig(supabase, 'apple_appstore', environment)

    const signedTransaction = receipt.receiptData
    if (!signedTransaction || signedTransaction.split('.').length !== 3) {
      return failure('Malformed StoreKit 2 transaction (expected a compact JWS)')
    }

    if (!config.bundleId) {
      return failure('Apple bundle ID not configured — cannot verify transaction')
    }
    if (!config.issuerId || !config.iapKeyId || !config.iapPrivateKey) {
      return failure('Apple App Store Server API credentials not configured — cannot verify transaction')
    }

    // Apple's getTransactionInfo accepts either identifier, but a plain transactionId
    // isn't always independently queryable for a renewed/restored subscription — try
    // it first, then fall back to originalTransactionId, per environment.
    let candidateIds: string[]
    try {
      const clientPayload = decodeJWSPayload(signedTransaction)
      candidateIds = [clientPayload.transactionId, clientPayload.originalTransactionId]
        .filter((id): id is string => typeof id === 'string' && id.length > 0)
      candidateIds = [...new Set(candidateIds)]
      if (candidateIds.length === 0) throw new Error('missing transactionId/originalTransactionId claims')
    } catch (e) {
      return failure(`Malformed StoreKit 2 transaction: ${describeError(e)}`)
    }

    const privateKey = await importApplePrivateKey(config.iapPrivateKey!)

    // A TestFlight/debug build produces Sandbox transactions even when the backend
    // resolves to production, so try the resolved environment first and fall back to
    // the other — mirroring the legacy 21007/21008 sandbox re-routing.
    const primaryEnv: AppleEnvironment = environment
    const fallbackEnv: AppleEnvironment = environment === 'production' ? 'sandbox' : 'production'

    const fetchTransactionById = async (env: AppleEnvironment, transactionId: string) => {
      const token = await createAppStoreServerAPIToken(config.issuerId!, config.iapKeyId!, config.bundleId!, privateKey)
      const res = await fetch(`${API_BASE_URL[env]}/inApps/v1/transactions/${transactionId}`, {
        headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
      })
      if (!res.ok) {
        let detail = `HTTP ${res.status}`
        try {
          const body = await res.json()
          if (body?.errorCode || body?.errorMessage) {
            detail = `HTTP ${res.status} errorCode=${body.errorCode} ${body.errorMessage ?? ''}`.trim()
          }
        } catch {
          // response body wasn't JSON — keep the plain HTTP status
        }
        throw new Error(detail)
      }
      const body = await res.json()
      if (!body.signedTransactionInfo) {
        throw new Error('Apple response missing signedTransactionInfo')
      }
      // Trusted: this JWS came directly from Apple over TLS in response to our own
      // authenticated request, so decoding without re-verifying its signature is safe.
      return decodeJWSPayload(body.signedTransactionInfo)
    }

    // Try every (environment, transactionId) combination — primary env first, each of
    // its candidate IDs, then the fallback env with the same ID order.
    const attempts: Array<{ env: AppleEnvironment; id: string }> = []
    for (const env of [primaryEnv, fallbackEnv]) {
      for (const id of candidateIds) attempts.push({ env, id })
    }

    const runAttempts = async () => {
      const errors: string[] = []
      let sawNotFound = false
      for (const { env, id } of attempts) {
        try {
          const result = await fetchTransactionById(env, id)
          if (env !== primaryEnv) console.log('[APPLE] Confirmed against fallback environment:', env)
          return { decoded: result, errors, sawNotFound }
        } catch (e) {
          if (e instanceof Error && e.message.includes('errorCode=4040010')) sawNotFound = true
          errors.push(`${env}[${id}]: ${describeError(e)}`)
        }
      }
      return { decoded: null, errors, sawNotFound }
    }

    // A brand-new (especially sandbox) transaction can take a couple of minutes to
    // become queryable via the Server API even though the purchase completed
    // instantly on-device — a 404 4040010 right after purchase usually just means
    // "not indexed yet". Retry a couple of times before failing; skip retries for
    // pure auth failures (401s), which waiting won't fix.
    const RETRY_DELAYS_MS = [5000, 10000]
    let outcome = await runAttempts()
    for (const delay of RETRY_DELAYS_MS) {
      if (outcome.decoded || !outcome.sawNotFound) break
      console.log(`[APPLE] Transaction not indexed yet — retrying in ${delay}ms`)
      await new Promise((resolve) => setTimeout(resolve, delay))
      outcome = await runAttempts()
    }

    const decoded: any = outcome.decoded
    if (!decoded) {
      console.error('[APPLE] Transaction lookup failed (all attempts):', outcome.errors)
      return failure(`Apple transaction lookup failed — ${outcome.errors.join(' | ')}`)
    }

    // Defense in depth: re-assert bundle ID even though it's implied by using it to
    // authenticate the API call, in case Apple's response ever includes a different app.
    if (config.bundleId && decoded.bundleId && decoded.bundleId !== config.bundleId) {
      return failure(
        `Bundle ID mismatch: transaction is for '${decoded.bundleId}', not '${config.bundleId}'`,
        decoded
      )
    }

    const purchaseDate = decoded.purchaseDate ? new Date(decoded.purchaseDate) : new Date()
    const expiryDate = decoded.expiresDate ? new Date(decoded.expiresDate) : undefined
    const now = new Date()
    // revocationDate present means Apple refunded/revoked the transaction (e.g. via
    // Family Sharing removal or support refund) — never valid regardless of expiry.
    const isActive = !decoded.revocationDate && (expiryDate ? expiryDate > now : true)

    // StoreKit 2 offer types: 1 = intro, 2 = promo, 3 = offer code. Trial is an
    // intro offer with a free payment mode; expose both flags for downstream use.
    const isIntroOffer = decoded.offerType === 1
    const isTrial = isIntroOffer

    console.log('[APPLE] Confirmed transaction:', {
      transactionId: decoded.transactionId,
      productId: decoded.productId,
      environment: decoded.environment,
      expiryDate,
      isActive,
      revocationDate: decoded.revocationDate,
    })

    if (!isActive) {
      const reason = decoded.revocationDate
        ? `revoked at ${new Date(decoded.revocationDate).toISOString()}`
        : `expired at ${expiryDate?.toISOString() ?? 'unknown'} (now: ${now.toISOString()})`
      return failure(
        `Apple confirmed the transaction but it is not currently active — ${reason}`,
        decoded
      )
    }

    return {
      isValid: isActive,
      transactionId: String(decoded.transactionId ?? ''),
      originalTransactionId: String(decoded.originalTransactionId ?? ''),
      purchaseDate,
      expiryDate,
      isTrial,
      isIntroOffer,
      // Auto-renew status is not part of the transaction payload; a live-active
      // subscription transaction implies auto-renew unless a renewal-info /
      // App Store Server Notification says otherwise (handled elsewhere).
      autoRenewing: isActive,
      validationResponse: decoded,
      validatedProductId: decoded.productId,
    }
  } catch (error) {
    console.error('[APPLE] Validation error:', error)
    return failure(error instanceof Error ? error.message : 'Unknown error')
  }
}
