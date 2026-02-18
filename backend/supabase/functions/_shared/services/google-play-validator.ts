/**
 * Google Play Receipt Validation Service
 *
 * Validates purchase receipts using Google Play Developer API.
 * Documentation: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2
 */

import { SupabaseClient } from '@supabase/supabase-js'
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

  try {
    // Get Google Play configuration
    const config = await getIAPConfig(supabase, 'google_play', environment)

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

      return {
        isValid: false,
        transactionId: '',
        purchaseDate: new Date(),
        isTrial: false,
        isIntroOffer: false,
        autoRenewing: false,
        validationResponse: null,
        error: `Google Play API error: ${response.status}`
      }
    }

    const validationData = await response.json()

    // Parse subscription state
    const subscriptionState = validationData.subscriptionState
    const lineItems = validationData.lineItems || []
    const latestOrderId = validationData.latestOrderId

    // Check if subscription is active
    const isActive = subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE' ||
                     subscriptionState === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'

    // Extract dates
    const startTime = lineItems[0]?.expiryTime?.seconds
      ? new Date(parseInt(lineItems[0].expiryTime.seconds) * 1000)
      : new Date()

    const expiryTime = lineItems[0]?.expiryTime?.seconds
      ? new Date(parseInt(lineItems[0].expiryTime.seconds) * 1000)
      : undefined

    // Check for trial or intro offer
    const offerDetails = lineItems[0]?.offerDetails
    const isTrial = offerDetails?.basePlanId?.includes('trial') || false
    const isIntroOffer = offerDetails?.offerType === 'INTRODUCTORY_OFFER' || false

    // Auto-renewing status
    const autoRenewing = validationData.canceledStateContext === null

    console.log('[GOOGLE_PLAY] Validation result:', {
      isValid: isActive,
      transactionId: latestOrderId,
      expiryDate: expiryTime,
      autoRenewing
    })

    return {
      isValid: isActive,
      transactionId: latestOrderId || receipt.purchaseToken,
      purchaseDate: startTime,
      expiryDate: expiryTime,
      isTrial,
      isIntroOffer,
      autoRenewing,
      validationResponse: validationData
    }
  } catch (error) {
    console.error('[GOOGLE_PLAY] Validation error:', error)

    return {
      isValid: false,
      transactionId: '',
      purchaseDate: new Date(),
      isTrial: false,
      isIntroOffer: false,
      autoRenewing: false,
      validationResponse: null,
      error: error instanceof Error ? error.message : 'Unknown error'
    }
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
export async function acknowledgeGooglePlayPurchase(
  supabase: SupabaseClient,
  receipt: GooglePlayReceipt,
  environment: 'sandbox' | 'production'
): Promise<boolean> {
  console.log('[GOOGLE_PLAY] Acknowledging purchase:', receipt.productId)

  try {
    const config = await getIAPConfig(supabase, 'google_play', environment)
    const accessToken = await getGoogleAccessToken(
      config.serviceAccountEmail!,
      config.serviceAccountKey!
    )

    const apiUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${receipt.packageName}/purchases/subscriptions/${receipt.productId}/tokens/${receipt.purchaseToken}:acknowledge`

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
