/**
 * Apple App Store Transaction Validation Service (StoreKit 2 / JWS)
 *
 * The app sends the StoreKit 2 signed transaction (JWSTransaction) obtained from
 * `PurchaseDetails.verificationData.serverVerificationData`. We verify it locally
 * against Apple's certificate chain using Apple's official app-store-server-library
 * (SignedDataVerifier) — no network round-trip to Apple, no App Store Server API
 * credentials, and the legacy verifyReceipt endpoint is no longer used.
 *
 * Docs: https://developer.apple.com/documentation/appstoreserverapi/jwstransaction
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignedDataVerifier, Environment } from 'npm:@apple/app-store-server-library@1.4.0'
import { Buffer } from 'node:buffer'
import { getIAPConfig } from './iap-config-service.ts'

export interface AppleReceiptData {
  receiptData: string  // StoreKit 2 JWSTransaction (compact JWS)
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

// Apple root certificates (public, stable). Fetched once per isolate and cached.
// Verification pins the chain to these roots, so a forged/altered JWS fails.
const APPLE_ROOT_CERT_URLS = [
  'https://www.apple.com/certificateauthority/AppleRootCA-G3.cer',
  'https://www.apple.com/certificateauthority/AppleRootCA-G2.cer',
]
let appleRootCertsCache: Buffer[] | null = null

async function getAppleRootCerts(): Promise<Buffer[]> {
  if (appleRootCertsCache) return appleRootCertsCache
  const certs: Buffer[] = []
  for (const url of APPLE_ROOT_CERT_URLS) {
    const res = await fetch(url)
    if (!res.ok) {
      throw new Error(`Failed to fetch Apple root cert ${url}: ${res.status}`)
    }
    certs.push(Buffer.from(await res.arrayBuffer()))
  }
  appleRootCertsCache = certs
  return certs
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

/**
 * Validate an Apple StoreKit 2 signed transaction (JWS).
 *
 * @param receipt.receiptData - the compact JWSTransaction string from the client
 * @param environment - resolved environment; the signed transaction's own
 *   environment claim must match, else validation fails.
 */
export async function validateAppleReceipt(
  supabase: SupabaseClient,
  receipt: AppleReceiptData,
  environment: 'sandbox' | 'production'
): Promise<AppleValidationResult> {
  console.log('[APPLE] Verifying StoreKit 2 transaction for environment:', environment)

  try {
    const config = await getIAPConfig(supabase, 'apple_appstore', environment)

    const signedTransaction = receipt.receiptData
    if (!signedTransaction || signedTransaction.split('.').length !== 3) {
      return failure('Malformed StoreKit 2 transaction (expected a compact JWS)')
    }

    // bundleId is required to verify the transaction is for this app. Fail closed
    // if it isn't configured rather than skip the check.
    if (!config.bundleId) {
      return failure('Apple bundle ID not configured — cannot verify transaction')
    }

    const appleRootCerts = await getAppleRootCerts()

    // The signature + cert chain are environment-independent, but SignedDataVerifier
    // also asserts the transaction's environment claim matches the one it was built
    // with. A debug/TestFlight build produces Sandbox transactions even when the
    // backend runs in production, so try the resolved environment first and fall
    // back to the other — mirroring the legacy 21007/21008 sandbox re-routing.
    const primaryEnv = environment === 'production' ? Environment.PRODUCTION : Environment.SANDBOX
    const fallbackEnv = primaryEnv === Environment.PRODUCTION ? Environment.SANDBOX : Environment.PRODUCTION

    const tryVerify = async (env: Environment) => {
      // enableOnlineChecks=false → offline signature + cert-chain verification only.
      const verifier = new SignedDataVerifier(appleRootCerts, false, env, config.bundleId!)
      return await verifier.verifyAndDecodeTransaction(signedTransaction)
    }

    let decoded: any
    try {
      decoded = await tryVerify(primaryEnv)
    } catch (primaryError) {
      try {
        decoded = await tryVerify(fallbackEnv)
        console.log('[APPLE] Verified against fallback environment:', fallbackEnv)
      } catch (fallbackError) {
        console.error('[APPLE] JWS verification failed (both environments):', primaryError, fallbackError)
        return failure(
          `Apple transaction verification failed: ${primaryError instanceof Error ? primaryError.message : 'invalid signature'}`
        )
      }
    }

    // Defense in depth: SignedDataVerifier already checks bundleId + environment,
    // but re-assert here so a library behavior change can't silently loosen it.
    if (config.bundleId && decoded.bundleId && decoded.bundleId !== config.bundleId) {
      return failure(
        `Bundle ID mismatch: transaction is for '${decoded.bundleId}', not '${config.bundleId}'`,
        decoded
      )
    }

    const purchaseDate = decoded.purchaseDate ? new Date(decoded.purchaseDate) : new Date()
    const expiryDate = decoded.expiresDate ? new Date(decoded.expiresDate) : undefined
    const now = new Date()
    const isActive = expiryDate ? expiryDate > now : true

    // StoreKit 2 offer types: 1 = intro, 2 = promo, 3 = offer code. Trial is an
    // intro offer with a free payment mode; expose both flags for downstream use.
    const isIntroOffer = decoded.offerType === 1
    const isTrial = isIntroOffer

    console.log('[APPLE] Verified transaction:', {
      transactionId: decoded.transactionId,
      productId: decoded.productId,
      environment: decoded.environment,
      expiryDate,
      isActive,
    })

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
