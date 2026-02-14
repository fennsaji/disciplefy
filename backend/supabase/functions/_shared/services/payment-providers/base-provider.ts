/**
 * Payment Provider Abstraction Layer
 *
 * Provides a unified interface for multiple payment providers:
 * - Razorpay (Web subscriptions)
 * - Google Play (Android in-app purchases)
 * - Apple App Store (iOS in-app purchases)
 */

// =====================================================
// TYPES & INTERFACES
// =====================================================

export type ProviderType = 'razorpay' | 'google_play' | 'apple_appstore'
export type ReceiptPlatform = 'ios' | 'android'

/**
 * Parameters for creating a subscription
 */
export interface CreateSubscriptionParams {
  userId: string
  planCode: string
  planId: string
  providerPlanId: string
  basePriceMinor: number
  currency: string
  discountedPriceMinor?: number
  promotionalCampaignId?: string | null
  userEmail?: string
  notes?: Record<string, unknown>
}

/**
 * Response from subscription creation
 */
export interface ProviderSubscriptionResponse {
  providerSubscriptionId: string
  status: string
  authorizationUrl?: string  // For Razorpay redirect flow
  metadata?: Record<string, unknown>
}

/**
 * Detailed subscription information from provider
 */
export interface ProviderSubscriptionDetails {
  providerSubscriptionId: string
  status: string
  planId: string
  currentPeriodStart?: Date
  currentPeriodEnd?: Date
  nextBillingAt?: Date
  totalCount?: number
  paidCount?: number
  remainingCount?: number
  metadata?: Record<string, unknown>
}

/**
 * Receipt validation result
 */
export interface ReceiptValidationResult {
  valid: boolean
  providerSubscriptionId: string
  productId: string
  transactionId: string
  purchaseDate: Date
  expiryDate?: Date
  status: 'active' | 'expired' | 'cancelled' | 'pending'
  metadata?: Record<string, unknown>
}

/**
 * Abstract Payment Provider Interface
 *
 * All payment providers must implement this interface to ensure
 * consistent behavior across different payment systems.
 */
export abstract class PaymentProvider {
  /**
   * Provider identifier
   */
  abstract readonly provider: ProviderType

  /**
   * Create a new subscription
   *
   * @param params - Subscription creation parameters
   * @returns Provider subscription response with ID and status
   */
  abstract createSubscription(
    params: CreateSubscriptionParams
  ): Promise<ProviderSubscriptionResponse>

  /**
   * Cancel an existing subscription
   *
   * @param providerSubscriptionId - External subscription ID from provider
   * @param cancelAtCycleEnd - If true, subscription remains active until period ends
   * @returns void on success, throws error on failure
   */
  abstract cancelSubscription(
    providerSubscriptionId: string,
    cancelAtCycleEnd: boolean
  ): Promise<void>

  /**
   * Resume a cancelled subscription (if supported)
   *
   * @param providerSubscriptionId - External subscription ID from provider
   * @returns void on success, throws error on failure
   */
  abstract resumeSubscription(
    providerSubscriptionId: string
  ): Promise<void>

  /**
   * Fetch subscription details from provider
   *
   * @param providerSubscriptionId - External subscription ID from provider
   * @returns Detailed subscription information
   */
  abstract fetchSubscription(
    providerSubscriptionId: string
  ): Promise<ProviderSubscriptionDetails>

  /**
   * Verify webhook signature (optional, provider-specific)
   *
   * Used by Razorpay to validate webhook authenticity
   *
   * @param payload - Raw webhook payload
   * @param signature - Signature from webhook headers
   * @returns true if signature is valid
   */
  verifyWebhookSignature?(payload: string, signature: string): boolean

  /**
   * Validate receipt from in-app purchase (optional, for IAP only)
   *
   * Used by Google Play and Apple App Store to validate purchase receipts
   *
   * @param receipt - Base64 encoded receipt or purchase token
   * @param platform - Platform identifier (ios or android)
   * @returns Validation result with subscription details
   */
  validateReceipt?(
    receipt: string,
    platform: ReceiptPlatform
  ): Promise<ReceiptValidationResult>
}

/**
 * Provider-specific errors
 */
export class ProviderError extends Error {
  constructor(
    message: string,
    public readonly provider: ProviderType,
    public readonly code: string,
    public readonly statusCode?: number
  ) {
    super(message)
    this.name = 'ProviderError'
  }
}

/**
 * Receipt validation errors
 */
export class ReceiptValidationError extends Error {
  constructor(
    message: string,
    public readonly platform: ReceiptPlatform,
    public readonly code: string
  ) {
    super(message)
    this.name = 'ReceiptValidationError'
  }
}
