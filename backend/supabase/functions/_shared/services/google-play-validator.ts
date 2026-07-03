/**
 * Google Play Receipt Validation Service
 *
 * Validates purchase receipts using Google Play Developer API.
 * Documentation: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getIAPConfig } from './iap-config-service.ts'
import * as jose from 'npm:jose@5'

export interface GooglePlayReceipt {
  packageName: string
  productId: string
  purchaseToken: string
}

export interface GooglePlayValidationResult {
  isValid: boolean
  transactionId: string
  purchaseDate: Date
  expiryDate?: Date
  isTrial: boolean
  isIntroOffer: boolean
  autoRenewing: boolean
  validationResponse: any
  validatedProductId?: string  // store-confirmed product ID from lineItems[0]
  error?: string
}

/**
 * Validate Google Play purchase receipt
 */
export async function validateGooglePlayReceipt(
  supabase: SupabaseClient,
  receipt: GooglePlayReceipt,
  environment: 'sandbox' | 'production'
): Promise<GooglePlayValidationResult> {
  console.log('[GOOGLE_PLAY] Validating receipt for product:', receipt.productId)

  // USE_MOCK bypass — only allowed in sandbox/local; reject in production.
  if (Deno.env.get('USE_MOCK') === 'true') {
    if (Deno.env.get('APP_ENVIRONMENT') !== 'sandbox') {
      throw new Error('[GOOGLE_PLAY] USE_MOCK=true is not allowed in production (APP_ENVIRONMENT must be "sandbox")')
    }
    console.log('[GOOGLE_PLAY] USE_MOCK=true — skipping real API call, returning mock valid result')
    return {
      isValid: true,
      transactionId: receipt.purchaseToken,
      purchaseDate: new Date(),
      expiryDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
      isTrial: false,
      isIntroOffer: false,
      autoRenewing: true,
      validationResponse: { mock: true, productId: receipt.productId },
      validatedProductId: receipt.productId
    }
  }

  try {
    // Get Google Play configuration
    const config = await getIAPConfig(supabase, 'google_play', environment)

    // Validate package name matches config
    if (receipt.packageName !== config.packageName) {
      return {
        isValid: false,
        error: `Package name mismatch: expected ${config.packageName}, got ${receipt.packageName}`,
        transactionId: receipt.purchaseToken,
        purchaseDate: new Date(0),
        autoRenewing: false,
        isTrial: false,
        isIntroOffer: false,
        validationResponse: null
      }
    }

    // Get access token using service account
    const accessToken = await getGoogleAccessToken(
      config.serviceAccountEmail!,
      config.serviceAccountKey!
    )

    // Call Google Play Developer API
    const apiUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${receipt.packageName}/purchases/subscriptionsv2/tokens/${receipt.purchaseToken}`

    const response = await fetch(apiUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('[GOOGLE_PLAY] API Error:', response.status, errorText)

      // H2: Distinguish transient (5xx / network) from terminal (404 = invalid token).
      // Transient errors must not return isValid:false — the frontend treats that as
      // INVALID_RECEIPT and permanently clears the transaction from the store queue.
      // Throw instead so the caller returns HTTP 503 and the client can retry.
      if (response.status === 404) {
        // 404 = purchase token not found = genuinely invalid receipt
        return {
          isValid: false,
          transactionId: receipt.purchaseToken,
          purchaseDate: new Date(),
          isTrial: false,
          isIntroOffer: false,
          autoRenewing: false,
          validationResponse: null,
          error: `Google Play API error: ${response.status}`
        }
      }
      // 5xx or other unexpected status = transient error
      throw new Error(`VALIDATION_UNAVAILABLE: Google Play API returned ${response.status} — retry later`)
    }

    const validationData = await response.json()

    // Parse subscription state
    const subscriptionState = validationData.subscriptionState
    const lineItems = validationData.lineItems || []
    const latestOrderId = validationData.latestOrderId

    // Extract dates first — needed for the canceled-but-unexpired check below.
    // Android Publisher v3 returns RFC3339 strings, not protobuf {seconds} objects.
    const startTime = validationData.startTime
      ? new Date(validationData.startTime)
      : new Date()

    const expiryTime = lineItems[0]?.expiryTime
      ? new Date(lineItems[0].expiryTime)
      : undefined

    // Check if subscription is active.
    // SUBSCRIPTION_STATE_CANCELED means the user canceled but access persists until
    // expiryTime — entitlement must be granted until then. Without this check,
    // canceled-but-paid subs return isValid:false, which causes INVALID_RECEIPT and
    // the purchase is permanently cleared from the queue on the client, losing access.
    const isActive = subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE' ||
                     subscriptionState === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' ||
                     (subscriptionState === 'SUBSCRIPTION_STATE_CANCELED' &&
                      expiryTime != null && expiryTime > new Date())

    // Check for trial or intro offer
    const offerDetails = lineItems[0]?.offerDetails
    const isTrial = offerDetails?.offerType === 'FREE_TRIAL'
    const isIntroOffer = offerDetails?.offerType === 'INTRODUCTORY_OFFER' || false

    // Auto-renewing status (== catches both null and undefined)
    const autoRenewing = validationData.canceledStateContext == null

    console.log('[GOOGLE_PLAY] Validation result:', {
      isValid: isActive,
      transactionId: latestOrderId,
      expiryDate: expiryTime,
      autoRenewing
    })

    return {
      isValid: isActive,
      transactionId: receipt.purchaseToken,
      purchaseDate: startTime,
      expiryDate: expiryTime,
      isTrial,
      isIntroOffer,
      autoRenewing,
      validationResponse: validationData,
      validatedProductId: lineItems[0]?.productId
    }
  } catch (error) {
    // H2: Re-throw VALIDATION_UNAVAILABLE (transient) so callers return 503 instead
    // of treating the error as INVALID_RECEIPT.  All other errors are also re-thrown
    // because a network failure is not evidence the receipt is invalid.
    console.error('[GOOGLE_PLAY] Validation error:', error)
    throw error
  }
}

/**
 * Get Google Cloud access token using service account
 */
async function getGoogleAccessToken(
  serviceAccountEmail: string,
  serviceAccountKeyJson: string
): Promise<string> {
  // Parse service account key
  const serviceAccount = JSON.parse(serviceAccountKeyJson)

  // Create JWT for Google OAuth 2.0
  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now
  }

  // Sign JWT using jose library
  const jwt = await signJWT(claims, serviceAccount.private_key)

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  })

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text()
    throw new Error(`Failed to get Google access token: ${errorText}`)
  }

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

/**
 * Sign JWT using RS256 algorithm with jose library
 */
async function signJWT(claims: any, privateKey: string): Promise<string> {
  try {
    // Import the private key
    const key = await jose.importPKCS8(privateKey, 'RS256')

    // Create and sign the JWT
    const jwt = await new jose.SignJWT(claims)
      .setProtectedHeader({ alg: 'RS256' })
      .sign(key)

    return jwt
  } catch (error) {
    console.error('[GOOGLE_PLAY] JWT signing error:', error)
    throw new Error(`Failed to sign JWT: ${error instanceof Error ? error.message : 'Unknown error'}`)
  }
}

/**
 * Acknowledge Google Play purchase
 */
/**
 * Cancel a Google Play subscription via the Android Publisher API.
 *
 * @param supabase - Supabase client (for reading service account credentials from iap_config)
 * @param packageName - App package name (e.g. com.disciplefy.bible_study)
 * @param productId   - Subscription product ID (e.g. plus_monthly)
 * @param purchaseToken - The purchase token from the original IAP purchase
 * @param environment - 'sandbox' or 'production'
 * @returns true on success, false on failure (non-throwing)
 */
export async function cancelGooglePlaySubscription(
  supabase: SupabaseClient,
  packageName: string,
  productId: string,
  purchaseToken: string,
  environment: 'sandbox' | 'production'
): Promise<boolean> {
  console.log('[GOOGLE_PLAY] Cancelling subscription:', { packageName, productId })

  if (Deno.env.get('USE_MOCK') === 'true') {
    console.log('[GOOGLE_PLAY] USE_MOCK=true — skipping cancel API call')
    return true
  }

  try {
    const config = await getIAPConfig(supabase, 'google_play', environment)
    const accessToken = await getGoogleAccessToken(
      config.serviceAccountEmail!,
      config.serviceAccountKey!
    )

    const apiUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/purchases/subscriptions/${productId}/tokens/${purchaseToken}:cancel`

    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    })

    if (!response.ok) {
      const errorBody = await response.text()
      console.error('[GOOGLE_PLAY] Cancel subscription failed:', response.status, errorBody)
      return false
    }

    console.log('[GOOGLE_PLAY] Subscription cancelled successfully')
    return true
  } catch (error) {
    console.error('[GOOGLE_PLAY] Cancel subscription error:', error)
    return false
  }
}

export async function acknowledgeGooglePlayPurchase(
  supabase: SupabaseClient,
  receipt: GooglePlayReceipt,
  environment: 'sandbox' | 'production'
): Promise<boolean> {
  console.log('[GOOGLE_PLAY] Acknowledging purchase:', receipt.productId)

  if (Deno.env.get('USE_MOCK') === 'true') {
    console.log('[GOOGLE_PLAY] USE_MOCK=true — skipping acknowledgment API call')
    return true
  }

  try {
    const config = await getIAPConfig(supabase, 'google_play', environment)
    const accessToken = await getGoogleAccessToken(
      config.serviceAccountEmail!,
      config.serviceAccountKey!
    )

    const apiUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${receipt.packageName}/purchases/subscriptionsv2/tokens/${receipt.purchaseToken}:acknowledge`

    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    })

    return response.ok
  } catch (error) {
    console.error('[GOOGLE_PLAY] Acknowledge error:', error)
    return false
  }
}
