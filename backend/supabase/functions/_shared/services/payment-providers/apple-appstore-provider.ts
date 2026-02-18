/**
 * Apple App Store Payment Provider Implementation
 *
 * Handles iOS in-app purchase subscription operations including:
 * - Receipt validation with Apple verifyReceipt API
 * - Subscription status synchronization
 * - Transaction verification
 *
 * Note: This uses the legacy verifyReceipt API. For production, consider:
 * 1. Migrating to App Store Server API (REST API with JWT auth)
 * 2. Implementing App Store Server Notifications V2
 * 3. Using StoreKit 2 transaction verification
 */

import {
  PaymentProvider,
  ProviderType,
  CreateSubscriptionParams,
  ProviderSubscriptionResponse,
  ProviderSubscriptionDetails,
  ReceiptValidationResult,
  ReceiptPlatform,
  ProviderError,
  ReceiptValidationError
} from './base-provider.ts'

/**
 * Apple receipt validation response
 */
interface AppleReceiptResponse {
  status: number
  environment: string
  receipt: {
    receipt_type: string
    bundle_id: string
    application_version: string
    original_application_version: string
    in_app: AppleInAppPurchase[]
  }
  latest_receipt_info?: AppleInAppPurchase[]
  pending_renewal_info?: Array<{
    auto_renew_product_id: string
    product_id: string
    original_transaction_id: string
    auto_renew_status: string
    expiration_intent?: string
  }>
  'is-retryable'?: boolean
}

interface AppleInAppPurchase {
  quantity: string
  product_id: string
  transaction_id: string
  original_transaction_id: string
  purchase_date: string
  purchase_date_ms: string
  purchase_date_pst: string
  original_purchase_date: string
  original_purchase_date_ms: string
  original_purchase_date_pst: string
  expires_date?: string
  expires_date_ms?: string
  expires_date_pst?: string
  web_order_line_item_id?: string
  is_trial_period?: string
  is_in_intro_offer_period?: string
  subscription_group_identifier?: string
  cancellation_date?: string
  cancellation_date_ms?: string
}

/**
 * AppleAppStoreProvider - Implements PaymentProvider for Apple App Store subscriptions
 */
export class AppleAppStoreProvider extends PaymentProvider {
  readonly provider: ProviderType = 'apple_appstore'
  private readonly productionUrl = 'https://buy.itunes.apple.com/verifyReceipt'
  private readonly sandboxUrl = 'https://sandbox.itunes.apple.com/verifyReceipt'
  private sharedSecret: string

  constructor() {
    super()
    this.sharedSecret = Deno.env.get('APPLE_SHARED_SECRET') || ''

    if (!this.sharedSecret) {
      console.warn('[AppleAppStoreProvider] Apple shared secret not configured')
    }
  }

  /**
   * Verify receipt with Apple
   *
   * @param receipt - Base64 encoded receipt data
   * @param useSandbox - If true, use sandbox environment
   */
  private async verifyWithApple(
    receipt: string,
    useSandbox = false
  ): Promise<AppleReceiptResponse> {
    const url = useSandbox ? this.sandboxUrl : this.productionUrl

    const requestBody = {
      'receipt-data': receipt,
      password: this.sharedSecret,
      'exclude-old-transactions': true
    }

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(requestBody)
    })

    if (!response.ok) {
      throw new Error(`Apple verification failed: ${response.status} ${response.statusText}`)
    }

    const data: AppleReceiptResponse = await response.json()

    // Status code 21007 means sandbox receipt sent to production - retry with sandbox
    if (data.status === 21007 && !useSandbox) {
      console.log('[AppleAppStoreProvider] Retrying with sandbox environment')
      return this.verifyWithApple(receipt, true)
    }

    return data
  }

  /**
   * Create subscription - Not applicable for Apple IAP
   *
   * Apple subscriptions are created on the client side.
   * This method validates the purchase after it's made.
   */
  async createSubscription(
    params: CreateSubscriptionParams
  ): Promise<ProviderSubscriptionResponse> {
    throw new ProviderError(
      'Apple App Store subscriptions are created client-side. Use validateReceipt() instead.',
      'apple_appstore',
      'METHOD_NOT_SUPPORTED',
      400
    )
  }

  /**
   * Cancel subscription - Handled through App Store
   */
  async cancelSubscription(
    providerSubscriptionId: string,
    cancelAtCycleEnd: boolean
  ): Promise<void> {
    throw new ProviderError(
      'Apple App Store subscription cancellation is managed by the user through Settings',
      'apple_appstore',
      'METHOD_NOT_SUPPORTED',
      400
    )
  }

  /**
   * Resume subscription - Handled through App Store
   */
  async resumeSubscription(providerSubscriptionId: string): Promise<void> {
    throw new ProviderError(
      'Apple App Store subscription resumption is managed by the user through Settings',
      'apple_appstore',
      'METHOD_NOT_SUPPORTED',
      400
    )
  }

  /**
   * Fetch subscription details from App Store
   *
   * @param providerSubscriptionId - Original transaction ID
   */
  async fetchSubscription(
    providerSubscriptionId: string
  ): Promise<ProviderSubscriptionDetails> {
    throw new ProviderError(
      'Use validateReceipt() to get Apple subscription details',
      'apple_appstore',
      'METHOD_NOT_SUPPORTED',
      400
    )
  }

  /**
   * Validate Apple App Store receipt
   *
   * @param receipt - Base64 encoded receipt data
   * @param platform - Must be 'ios'
   * @returns Validation result with subscription details
   */
  override async validateReceipt(
    receipt: string,
    platform: ReceiptPlatform
  ): Promise<ReceiptValidationResult> {
    if (platform !== 'ios') {
      throw new ReceiptValidationError(
        'Apple App Store provider only supports iOS platform',
        platform,
        'INVALID_PLATFORM'
      )
    }

    if (!this.sharedSecret) {
      throw new ReceiptValidationError(
        'Apple shared secret not configured',
        platform,
        'APPLE_NOT_CONFIGURED'
      )
    }

    try {
      // Verify receipt with Apple
      const response = await this.verifyWithApple(receipt)

      // Check validation status
      if (response.status !== 0) {
        const errorMessages: Record<number, string> = {
          21000: 'App Store could not read the receipt',
          21002: 'Receipt data is malformed',
          21003: 'Receipt could not be authenticated',
          21004: 'Shared secret does not match',
          21005: 'Receipt server is unavailable',
          21006: 'Receipt is valid but subscription has expired',
          21007: 'Sandbox receipt sent to production',
          21008: 'Production receipt sent to sandbox',
          21009: 'Internal data access error',
          21010: 'User account not found or deleted'
        }

        throw new ReceiptValidationError(
          errorMessages[response.status] || `Apple validation failed with status ${response.status}`,
          platform,
          `APPLE_STATUS_${response.status}`
        )
      }

      // Get latest subscription info
      const latestReceipt = response.latest_receipt_info?.[0] || response.receipt.in_app[0]

      if (!latestReceipt) {
        throw new ReceiptValidationError(
          'No subscription information found in receipt',
          platform,
          'NO_SUBSCRIPTION_INFO'
        )
      }

      // Determine subscription status
      let status: 'active' | 'expired' | 'cancelled' | 'pending'
      const now = Date.now()
      const expiryMs = parseInt(latestReceipt.expires_date_ms || '0')

      if (latestReceipt.cancellation_date_ms) {
        status = 'cancelled'
      } else if (expiryMs < now) {
        status = 'expired'
      } else if (expiryMs > now) {
        status = 'active'
      } else {
        status = 'pending'
      }

      // Check auto-renewal status
      const autoRenewStatus = response.pending_renewal_info?.[0]?.auto_renew_status

      return {
        valid: status === 'active',
        providerSubscriptionId: latestReceipt.original_transaction_id,
        productId: latestReceipt.product_id,
        transactionId: latestReceipt.transaction_id,
        purchaseDate: new Date(parseInt(latestReceipt.purchase_date_ms)),
        expiryDate: latestReceipt.expires_date_ms
          ? new Date(parseInt(latestReceipt.expires_date_ms))
          : undefined,
        status,
        metadata: {
          environment: response.environment,
          bundle_id: response.receipt.bundle_id,
          original_transaction_id: latestReceipt.original_transaction_id,
          web_order_line_item_id: latestReceipt.web_order_line_item_id,
          is_trial_period: latestReceipt.is_trial_period === 'true',
          is_in_intro_offer_period: latestReceipt.is_in_intro_offer_period === 'true',
          auto_renew_status: autoRenewStatus,
          subscription_group_identifier: latestReceipt.subscription_group_identifier,
          cancellation_date: latestReceipt.cancellation_date
        }
      }
    } catch (error: unknown) {
      console.error('[AppleAppStoreProvider] Receipt validation failed:', error)

      if (error instanceof ReceiptValidationError) {
        throw error
      }

      throw new ReceiptValidationError(
        error instanceof Error ? error.message : 'Failed to validate Apple receipt',
        platform,
        'RECEIPT_VALIDATION_FAILED'
      )
    }
  }
}
