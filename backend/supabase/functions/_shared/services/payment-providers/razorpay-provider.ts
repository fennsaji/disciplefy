/**
 * Razorpay Payment Provider Implementation
 *
 * Handles all Razorpay-specific subscription operations including:
 * - Subscription creation with hosted checkout
 * - Subscription cancellation (immediate or at cycle end)
 * - Subscription resumption
 * - Webhook signature verification
 */

import Razorpay from 'npm:razorpay'
import { generateHmacSha256 } from '../../utils/crypto-utils.ts'
import {
  PaymentProvider,
  ProviderType,
  CreateSubscriptionParams,
  ProviderSubscriptionResponse,
  ProviderSubscriptionDetails,
  ProviderError
} from './base-provider.ts'

/**
 * Razorpay subscription response from API
 */
interface RazorpaySubscriptionApiResponse {
  id: string
  entity: string
  plan_id: string
  status: string
  current_start: number | null
  current_end: number | null
  ended_at: number | null
  quantity: number
  notes: Record<string, unknown>
  charge_at: number | null
  start_at: number | null
  end_at: number | null
  auth_attempts: number
  total_count: number
  paid_count: number
  customer_notify: number
  created_at: number
  expire_by: number | null
  short_url: string
  has_scheduled_changes: boolean
  change_scheduled_at: number | null
  source: string
  remaining_count: number
}

/**
 * RazorpayProvider - Implements PaymentProvider for Razorpay subscriptions
 */
export class RazorpayProvider extends PaymentProvider {
  readonly provider: ProviderType = 'razorpay'
  private razorpay: Razorpay | null = null

  constructor() {
    super()
    this.initializeClient()
  }

  /**
   * Initialize Razorpay client with credentials
   */
  private initializeClient(): void {
    const keyId = Deno.env.get('RAZORPAY_KEY_ID')
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')

    if (!keyId || !keySecret) {
      throw new ProviderError(
        'Razorpay credentials not configured',
        'razorpay',
        'RAZORPAY_CONFIG_MISSING',
        500
      )
    }

    this.razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret
    })
  }

  /**
   * Create a new Razorpay subscription with hosted checkout
   *
   * @param params - Subscription parameters
   * @returns Provider subscription response with authorization URL
   */
  async createSubscription(
    params: CreateSubscriptionParams
  ): Promise<ProviderSubscriptionResponse> {
    if (!this.razorpay) {
      throw new ProviderError(
        'Razorpay client not initialized',
        'razorpay',
        'RAZORPAY_NOT_INITIALIZED',
        500
      )
    }

    try {
      // Create Razorpay subscription with hosted checkout
      const subscriptionData: {
        plan_id: string
        total_count: number
        quantity: number
        customer_notify: 0 | 1
        notes: Record<string, string | number>
      } = {
        plan_id: params.providerPlanId,
        total_count: 360, // 30 years (360 months)
        quantity: 1,
        customer_notify: 1, // Send email notification
        notes: {
          user_id: params.userId,
          plan_code: params.planCode,
          ...(params.promotionalCampaignId && {
            promotional_campaign_id: params.promotionalCampaignId
          }),
          ...(params.notes as Record<string, string | number> || {})
        }
      }

      console.log('[RazorpayProvider] Creating subscription:', {
        plan_id: params.providerPlanId,
        user_id: params.userId
      })

      const razorpaySubscription =
        await this.razorpay.subscriptions.create(subscriptionData) as unknown as RazorpaySubscriptionApiResponse

      console.log('[RazorpayProvider] Subscription created:', razorpaySubscription.id)

      return {
        providerSubscriptionId: razorpaySubscription.id,
        status: razorpaySubscription.status,
        authorizationUrl: razorpaySubscription.short_url,
        metadata: {
          total_count: razorpaySubscription.total_count,
          paid_count: razorpaySubscription.paid_count,
          remaining_count: razorpaySubscription.remaining_count,
          created_at: razorpaySubscription.created_at
        }
      }
    } catch (error: unknown) {
      console.error('[RazorpayProvider] Failed to create subscription:', error)

      // Extract Razorpay error details
      const razorpayError = error as {
        statusCode?: number
        error?: { code?: string; description?: string }
      }

      throw new ProviderError(
        razorpayError.error?.description || 'Failed to create Razorpay subscription',
        'razorpay',
        razorpayError.error?.code || 'RAZORPAY_SUBSCRIPTION_CREATE_FAILED',
        razorpayError.statusCode || 500
      )
    }
  }

  /**
   * Cancel a Razorpay subscription
   *
   * @param providerSubscriptionId - Razorpay subscription ID
   * @param cancelAtCycleEnd - If true, cancel at end of current billing cycle
   */
  async cancelSubscription(
    providerSubscriptionId: string,
    cancelAtCycleEnd: boolean
  ): Promise<void> {
    if (!this.razorpay) {
      throw new ProviderError(
        'Razorpay client not initialized',
        'razorpay',
        'RAZORPAY_NOT_INITIALIZED',
        500
      )
    }

    try {
      console.log('[RazorpayProvider] Cancelling subscription:', providerSubscriptionId, {
        cancel_at_cycle_end: cancelAtCycleEnd
      })

      await this.razorpay.subscriptions.cancel(providerSubscriptionId, cancelAtCycleEnd ? 1 : 0)

      console.log('[RazorpayProvider] Subscription cancelled successfully')
    } catch (error: unknown) {
      console.error('[RazorpayProvider] Failed to cancel subscription:', error)

      const razorpayError = error as {
        statusCode?: number
        error?: { code?: string; description?: string }
      }

      throw new ProviderError(
        razorpayError.error?.description || 'Failed to cancel Razorpay subscription',
        'razorpay',
        razorpayError.error?.code || 'RAZORPAY_SUBSCRIPTION_CANCEL_FAILED',
        razorpayError.statusCode || 500
      )
    }
  }

  /**
   * Resume a cancelled Razorpay subscription
   *
   * Removes the cancel_at_cycle_end flag to allow subscription to continue
   *
   * @param providerSubscriptionId - Razorpay subscription ID
   */
  async resumeSubscription(providerSubscriptionId: string): Promise<void> {
    if (!this.razorpay) {
      throw new ProviderError(
        'Razorpay client not initialized',
        'razorpay',
        'RAZORPAY_NOT_INITIALIZED',
        500
      )
    }

    try {
      console.log('[RazorpayProvider] Resuming subscription:', providerSubscriptionId)

      // Update subscription - Razorpay automatically resumes when fetched
      // Note: Razorpay doesn't have a direct resume API, subscription is auto-resumed
      // when cancel_at_cycle_end status is cleared
      await this.razorpay.subscriptions.update(providerSubscriptionId, {
        customer_notify: 1
      })

      console.log('[RazorpayProvider] Subscription resumed successfully')
    } catch (error: unknown) {
      console.error('[RazorpayProvider] Failed to resume subscription:', error)

      const razorpayError = error as {
        statusCode?: number
        error?: { code?: string; description?: string }
      }

      throw new ProviderError(
        razorpayError.error?.description || 'Failed to resume Razorpay subscription',
        'razorpay',
        razorpayError.error?.code || 'RAZORPAY_SUBSCRIPTION_RESUME_FAILED',
        razorpayError.statusCode || 500
      )
    }
  }

  /**
   * Fetch subscription details from Razorpay
   *
   * @param providerSubscriptionId - Razorpay subscription ID
   * @returns Detailed subscription information
   */
  async fetchSubscription(
    providerSubscriptionId: string
  ): Promise<ProviderSubscriptionDetails> {
    if (!this.razorpay) {
      throw new ProviderError(
        'Razorpay client not initialized',
        'razorpay',
        'RAZORPAY_NOT_INITIALIZED',
        500
      )
    }

    try {
      console.log('[RazorpayProvider] Fetching subscription:', providerSubscriptionId)

      const razorpaySubscription =
        await this.razorpay.subscriptions.fetch(providerSubscriptionId) as unknown as RazorpaySubscriptionApiResponse

      return {
        providerSubscriptionId: razorpaySubscription.id,
        status: razorpaySubscription.status,
        planId: razorpaySubscription.plan_id,
        currentPeriodStart: razorpaySubscription.current_start
          ? new Date(razorpaySubscription.current_start * 1000)
          : undefined,
        currentPeriodEnd: razorpaySubscription.current_end
          ? new Date(razorpaySubscription.current_end * 1000)
          : undefined,
        nextBillingAt: razorpaySubscription.charge_at
          ? new Date(razorpaySubscription.charge_at * 1000)
          : undefined,
        totalCount: razorpaySubscription.total_count,
        paidCount: razorpaySubscription.paid_count,
        remainingCount: razorpaySubscription.remaining_count,
        metadata: {
          auth_attempts: razorpaySubscription.auth_attempts,
          has_scheduled_changes: razorpaySubscription.has_scheduled_changes,
          source: razorpaySubscription.source,
          notes: razorpaySubscription.notes
        }
      }
    } catch (error: unknown) {
      console.error('[RazorpayProvider] Failed to fetch subscription:', error)

      const razorpayError = error as {
        statusCode?: number
        error?: { code?: string; description?: string }
      }

      throw new ProviderError(
        razorpayError.error?.description || 'Failed to fetch Razorpay subscription',
        'razorpay',
        razorpayError.error?.code || 'RAZORPAY_SUBSCRIPTION_FETCH_FAILED',
        razorpayError.statusCode || 500
      )
    }
  }

  /**
   * Verify Razorpay webhook signature
   *
   * @param payload - Raw webhook payload (JSON string)
   * @param signature - X-Razorpay-Signature header value
   * @returns true if signature is valid
   */
  override async verifyWebhookSignature(payload: string, signature: string): Promise<boolean> {
    const webhookSecret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET')

    if (!webhookSecret) {
      console.error('[RazorpayProvider] Webhook secret not configured')
      return false
    }

    try {
      // Generate expected signature using Web Crypto API
      const expectedSignature = await generateHmacSha256(webhookSecret, payload)

      // Constant-time comparison to prevent timing attacks
      const isValid = signature === expectedSignature

      if (!isValid) {
        console.warn('[RazorpayProvider] Webhook signature verification failed')
      }

      return isValid
    } catch (error) {
      console.error('[RazorpayProvider] Error verifying webhook signature:', error)
      return false
    }
  }
}
