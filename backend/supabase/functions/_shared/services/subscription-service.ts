/**
 * Subscription Service
 *
 * Centralized service for managing Razorpay premium subscriptions.
 * Handles subscription lifecycle: creation, cancellation, status sync.
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import type { PostgrestError } from 'https://esm.sh/@supabase/supabase-js@2'
import Razorpay from 'npm:razorpay'
import { AppError } from '../utils/error-handler.ts'
import {
  Subscription,
  SubscriptionStatus,
  SubscriptionEventType,
  RazorpaySubscriptionResponse,
  CreateSubscriptionOptions,
  CancelSubscriptionOptions,
  SubscriptionServiceConfig,
  DEFAULT_SUBSCRIPTION_CONFIG,
  SubscriptionPlanType
} from '../types/subscription-types.ts'
import { getPlanConfig, PlanType } from '../config/subscription-config.ts'

/**
 * SubscriptionService implementation
 *
 * Provides methods for creating, cancelling, and managing premium subscriptions
 */
export class SubscriptionService {
  private readonly config: SubscriptionServiceConfig
  private razorpay: Razorpay | null = null

  /**
   * Creates a new SubscriptionService instance
   *
   * @param supabaseClient - Configured Supabase client with service role access
   * @param config - Optional subscription service configuration
   */
  constructor(
    private readonly supabaseClient: SupabaseClient,
    config?: Partial<SubscriptionServiceConfig>
  ) {
    // Get plan ID from environment
    const envPlanId = Deno.env.get('RAZORPAY_PREMIUM_PLAN_ID')

    this.config = {
      ...DEFAULT_SUBSCRIPTION_CONFIG,
      ...config,
      planId: config?.planId || envPlanId || ''
    }

    this.initializeRazorpay()
  }

  /**
   * Initialize Razorpay client
   */
  private initializeRazorpay(): void {
    const keyId = Deno.env.get('RAZORPAY_KEY_ID')
    const keySecret = Deno.env.get('RAZORPAY_KEY_SECRET')

    if (!keyId || !keySecret) {
      console.warn('[SubscriptionService] Razorpay credentials not configured')
      return
    }

    this.razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret
    })
  }

  /**
   * Creates a new premium subscription for a user
   *
   * This method:
   * 1. Validates no existing active subscription
   * 2. Gets or creates Razorpay customer
   * 3. Creates Razorpay subscription
   * 4. Stores subscription in database
   * 5. Returns authorization URL for customer
   *
   * @param options - Subscription creation options
   * @returns Promise resolving to subscription details with authorization URL
   * @throws AppError when user already has subscription or creation fails
   */
  async createSubscription(options: CreateSubscriptionOptions): Promise<{
    subscription: Subscription
    shortUrl: string
  }> {
    this.validateConfiguration()

    // Check for existing active subscription
    await this.ensureNoActiveSubscription(options.userId)

    // Capture Razorpay subscription in outer scope for cleanup on failure
    let razorpaySubscription: RazorpaySubscriptionResponse | undefined

    try {
      // ✅ FIX: Don't pre-create customer for hosted checkout
      // The hosted checkout page will create the customer during payment authorization
      // We'll receive the customer_id via webhook when subscription is authenticated
      razorpaySubscription = await this.createRazorpaySubscription(options)

      // Store subscription in database with plan type
      const subscription = await this.storeSubscription(
        options.userId,
        razorpaySubscription,
        options.planType
      )

      // Log creation event
      await this.logSubscriptionEvent(
        subscription.id,
        options.userId,
        'subscription.created',
        null,
        'created',
        null,
        null,
        null,
        { razorpay_response: razorpaySubscription }
      )

      return {
        subscription,
        shortUrl: razorpaySubscription.short_url
      }
    } catch (error) {
      // If Razorpay subscription was created but subsequent operations failed,
      // attempt to cancel it to prevent orphaned subscriptions
      if (razorpaySubscription) {
        try {
          console.warn(
            '[SubscriptionService] Attempting cleanup: cancelling orphaned Razorpay subscription',
            razorpaySubscription.id
          )
          await this.cancelRazorpaySubscription(razorpaySubscription.id, false)
          console.log(
            '[SubscriptionService] Successfully cancelled orphaned subscription:',
            razorpaySubscription.id
          )
        } catch (cleanupError) {
          // Log cleanup failure but don't mask the original error
          console.error(
            '[SubscriptionService] Failed to cancel orphaned Razorpay subscription:',
            razorpaySubscription.id,
            cleanupError
          )
        }
      }

      // Re-throw original error
      if (error instanceof AppError) {
        throw error
      }

      console.error('[SubscriptionService] Failed to create subscription:', error)
      throw new AppError(
        'SUBSCRIPTION_CREATION_ERROR',
        'Failed to create subscription',
        500
      )
    }
  }

  /**
   * Cancels an existing subscription
   *
   * @param options - Cancellation options
   * @returns Promise resolving to updated subscription
   * @throws AppError when subscription not found or cancellation fails
   */
  async cancelSubscription(options: CancelSubscriptionOptions): Promise<Subscription> {
    // Get existing subscription
    const subscription = await this.getSubscription(
      options.subscriptionId,
      options.userId
    )

    if (!subscription) {
      throw new AppError(
        'SUBSCRIPTION_NOT_FOUND',
        'Subscription not found',
        404
      )
    }

    if (subscription.status === 'cancelled' || subscription.status === 'expired') {
      throw new AppError(
        'SUBSCRIPTION_ALREADY_CANCELLED',
        'Subscription is already cancelled',
        400
      )
    }

    try {
      // Validate configuration before calling Razorpay
      this.validateConfiguration()

      if (options.cancelAtCycleEnd) {
        // Cancel at cycle end: Set flag in Razorpay, subscription stays active
        console.log('[SubscriptionService] Cancelling at cycle end in Razorpay:', subscription.id)
        await this.cancelRazorpaySubscription(
          subscription.razorpay_subscription_id,
          true  // cancel_at_cycle_end = 1
        )

        // Update database to pending_cancellation (still active with premium)
        const updatedSubscription = await this.updateSubscriptionStatus(
          subscription.id,
          'pending_cancellation',
          {
            cancelled_at: new Date().toISOString(),
            cancel_at_cycle_end: true,
            cancellation_reason: options.reason || null
          }
        )

        // Log cancellation event
        await this.logSubscriptionEvent(
          subscription.id,
          options.userId,
          'subscription.cancelled',
          subscription.status,
          'pending_cancellation',
          null,
          null,
          null,
          {
            cancel_at_cycle_end: true,
            reason: options.reason,
            razorpay_cancel_at_cycle_end_set: true
          }
        )

        return updatedSubscription
      } else {
        // Cancel immediately: Cancel in Razorpay, subscription ends now
        console.log('[SubscriptionService] Cancelling immediately in Razorpay:', subscription.id)
        await this.cancelRazorpaySubscription(
          subscription.razorpay_subscription_id,
          false  // cancel_at_cycle_end = 0
        )

        // Update database to cancelled (no longer active)
        const updatedSubscription = await this.updateSubscriptionStatus(
          subscription.id,
          'cancelled',
          {
            cancelled_at: new Date().toISOString(),
            cancel_at_cycle_end: false,
            cancellation_reason: options.reason || null
          }
        )

        // Log cancellation event
        await this.logSubscriptionEvent(
          subscription.id,
          options.userId,
          'subscription.cancelled',
          subscription.status,
          'cancelled',
          null,
          null,
          null,
          {
            cancel_at_cycle_end: false,
            reason: options.reason,
            razorpay_cancelled_immediately: true
          }
        )

        return updatedSubscription
      }
    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      console.error('[SubscriptionService] Failed to cancel subscription:', error)
      throw new AppError(
        'SUBSCRIPTION_CANCELLATION_ERROR',
        'Failed to cancel subscription',
        500
      )
    }
  }

  /**
   * Resumes a cancelled subscription
   *
   * Reactivates a subscription that was previously cancelled with cancel_at_cycle_end=true.
   * The subscription must still be within its active billing period.
   *
   * @param options - Resume options containing subscriptionId and userId
   * @returns Promise resolving to updated subscription
   * @throws AppError if subscription not found, not cancelled, or expired
   */
  async resumeSubscription(options: {
    subscriptionId: string
    userId: string
  }): Promise<Subscription> {
    const subscription = await this.getSubscription(
      options.subscriptionId,
      options.userId
    )

    if (!subscription) {
      throw new AppError(
        'SUBSCRIPTION_NOT_FOUND',
        'Subscription not found',
        404
      )
    }

    if (subscription.status !== 'pending_cancellation') {
      throw new AppError(
        'SUBSCRIPTION_NOT_PENDING_CANCELLATION',
        'Only subscriptions with pending cancellation can be resumed',
        400
      )
    }

    // Check if still within billing period
    if (subscription.current_period_end) {
      const periodEnd = new Date(subscription.current_period_end)
      const now = new Date()
      if (periodEnd <= now) {
        throw new AppError(
          'SUBSCRIPTION_EXPIRED',
          'Subscription period has expired and cannot be resumed',
          400
        )
      }
    }

    try {
      // Validate configuration before calling Razorpay
      this.validateConfiguration()

      // Remove cancel_at_cycle_end flag in Razorpay
      console.log('[SubscriptionService] Removing cancel_at_cycle_end flag in Razorpay:', subscription.id)
      await this.resumeRazorpaySubscription(subscription.razorpay_subscription_id)

      // Update database - set status back to active and clear cancellation fields
      const updatedSubscription = await this.updateSubscriptionStatus(
        subscription.id,
        'active',
        {
          cancelled_at: null,
          cancel_at_cycle_end: false,
          cancellation_reason: null
        }
      )

      // Log resume event
      await this.logSubscriptionEvent(
        subscription.id,
        options.userId,
        'subscription.resumed',
        'pending_cancellation',
        'active',
        null,
        null,
        null,
        {
          resumed_from_pending_cancellation: true,
          razorpay_cancel_flag_removed: true
        }
      )

      console.log('[SubscriptionService] Subscription resumed successfully:', subscription.id)

      return updatedSubscription
    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }

      console.error('[SubscriptionService] Failed to resume subscription:', error)
      throw new AppError(
        'SUBSCRIPTION_RESUME_ERROR',
        'Failed to resume subscription',
        500
      )
    }
  }

  /**
   * Gets subscription details for a user
   *
   * @param subscriptionId - Subscription UUID
   * @param userId - User UUID for ownership verification
   * @returns Promise resolving to subscription or null
   */
  async getSubscription(
    subscriptionId: string,
    userId: string
  ): Promise<Subscription | null> {
    const { data, error } = await this.supabaseClient
      .from('subscriptions')
      .select('*')
      .eq('id', subscriptionId)
      .eq('user_id', userId)
      .maybeSingle() as { data: Subscription | null, error: PostgrestError | null }

    if (error) {
      console.error('[SubscriptionService] Failed to fetch subscription:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to fetch subscription',
        500
      )
    }

    return data
  }

  /**
   * Gets active subscription for a user
   *
   * Note: Includes 'pending_cancellation' to prevent duplicate subscriptions.
   * A user with pending_cancellation still has an active subscription until period end.
   *
   * @param userId - User UUID
   * @returns Promise resolving to active subscription or null
   */
  async getActiveSubscription(userId: string): Promise<Subscription | null> {
    const { data, error } = await this.supabaseClient
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .in('status', ['active', 'authenticated', 'pending_cancellation'])
      .maybeSingle() as { data: Subscription | null, error: PostgrestError | null }

    if (error && error.code !== 'PGRST116') {
      console.error('[SubscriptionService] Failed to fetch active subscription:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to fetch subscription',
        500
      )
    }

    return data
  }

  /**
   * Syncs subscription status from Razorpay
   *
   * @param subscriptionId - Database subscription UUID
   * @returns Promise resolving to updated subscription
   */
  async syncSubscriptionFromRazorpay(subscriptionId: string): Promise<Subscription> {
    this.validateConfiguration()

    const { data: subscription } = await this.supabaseClient
      .from('subscriptions')
      .select('razorpay_subscription_id, user_id')
      .eq('id', subscriptionId)
      .single() as { data: { razorpay_subscription_id: string, user_id: string } | null }

    if (!subscription) {
      throw new AppError(
        'SUBSCRIPTION_NOT_FOUND',
        'Subscription not found',
        404
      )
    }

    try {
      const razorpayData = await this.fetchRazorpaySubscription(
        subscription.razorpay_subscription_id
      )

      return await this.updateSubscriptionFromRazorpay(
        subscriptionId,
        subscription.user_id,
        razorpayData
      )
    } catch (error) {
      console.error('[SubscriptionService] Failed to sync subscription:', error)
      throw new AppError(
        'SUBSCRIPTION_SYNC_ERROR',
        'Failed to sync subscription from Razorpay',
        500
      )
    }
  }

  /**
   * Gets or creates a Razorpay customer for a user
   */
  private async getOrCreateRazorpayCustomer(userId: string): Promise<string> {
    // Check if user already has a Razorpay customer ID
    const { data: profile } = await this.supabaseClient
      .from('user_profiles')
      .select('razorpay_customer_id')
      .eq('id', userId)
      .single()

    if (profile?.razorpay_customer_id) {
      console.log('[SubscriptionService] Using existing Razorpay customer:', profile.razorpay_customer_id)
      return profile.razorpay_customer_id
    }

    // Get user email from auth.users
    const { data: authUser } = await this.supabaseClient.auth.admin.getUserById(userId)

    if (!authUser?.user?.email) {
      throw new AppError(
        'USER_EMAIL_REQUIRED',
        'User email is required to create a subscription',
        400
      )
    }

    if (!this.razorpay) {
      throw new AppError(
        'PAYMENT_SERVICE_ERROR',
        'Payment service not configured',
        500
      )
    }

    try {
      // Create Razorpay customer
      const customer = await this.razorpay.customers.create({
        email: authUser.user.email,
        notes: {
          user_id: userId
        }
      }) as any

      console.log('[SubscriptionService] Razorpay customer created:', customer.id)

      // Store customer ID in user_profiles
      await this.supabaseClient
        .from('user_profiles')
        .update({ razorpay_customer_id: customer.id })
        .eq('id', userId)

      return customer.id
    } catch (error: any) {
      console.error('[SubscriptionService] Failed to create Razorpay customer:', error)
      throw new AppError(
        'RAZORPAY_ERROR',
        error?.error?.description || 'Failed to create customer with payment provider',
        500
      )
    }
  }

  /**
   * Creates a Razorpay subscription
   *
   * ✅ FIX: customer_id is NOT provided for hosted checkout
   * Razorpay's hosted checkout page will create the customer during payment
   * The customer_id will be returned in the webhook when subscription is authenticated
   */
  private async createRazorpaySubscription(
    options: CreateSubscriptionOptions
  ): Promise<RazorpaySubscriptionResponse> {
    if (!this.razorpay) {
      throw new AppError(
        'PAYMENT_SERVICE_ERROR',
        'Payment service not configured',
        500
      )
    }

    // Get plan configuration based on plan type
    const planConfig = await getPlanConfig(options.planType as PlanType)
    const planId = planConfig.planId || this.config.planId

    if (!planId) {
      throw new AppError(
        'CONFIGURATION_ERROR',
        `Plan ID not configured for ${options.planType} plan`,
        500
      )
    }

    try {
      // Build subscription request - omit total_count if null (unlimited)
      const subscriptionRequest: Record<string, any> = {
        plan_id: planId,
        // ❌ REMOVED: customer_id - Let hosted checkout create the customer
        customer_notify: this.config.customerNotify,
        quantity: 1,
        notes: {
          user_id: options.userId,
          plan_type: options.planType,  // Store plan type in notes for webhook
          subscription_type: `${options.planType}_monthly`,
          ...options.notes
        }
      }

      // ✅ FIX: Only include start_at if it has a valid value
      // Passing undefined causes Razorpay to throw "end_time must be between..." error
      if (options.startAt) {
        subscriptionRequest.start_at = options.startAt
      }

      // ✅ Handle total_count for unlimited vs limited subscriptions
      // Razorpay requires either total_count OR end_at
      // UPI payments have a 30-year limit (360 months)
      // Using 360 to support all payment methods including UPI
      // For limited: use the specified count
      subscriptionRequest.total_count = this.config.totalCount ?? 360

      console.log('[SubscriptionService] Creating subscription with request:', JSON.stringify(subscriptionRequest, null, 2))
      console.log('[SubscriptionService] Config totalCount:', this.config.totalCount)
      console.log('[SubscriptionService] Final total_count sent to Razorpay:', subscriptionRequest.total_count)

      const subscription = await this.razorpay.subscriptions.create(
        subscriptionRequest as any
      ) as unknown as RazorpaySubscriptionResponse

      console.log('[SubscriptionService] Razorpay subscription created:', subscription.id)
      return subscription
    } catch (error: any) {
      console.error('[SubscriptionService] Razorpay API error:', error)
      throw new AppError(
        'RAZORPAY_ERROR',
        error?.error?.description || 'Failed to create subscription with payment provider',
        500
      )
    }
  }

  /**
   * Cancels a Razorpay subscription
   */
  private async cancelRazorpaySubscription(
    razorpaySubscriptionId: string,
    cancelAtCycleEnd: boolean
  ): Promise<void> {
    if (!this.razorpay) {
      throw new AppError(
        'PAYMENT_SERVICE_ERROR',
        'Payment service not configured',
        500
      )
    }

    try {
      await this.razorpay.subscriptions.cancel(razorpaySubscriptionId, cancelAtCycleEnd ? 1 : 0)

      console.log('[SubscriptionService] Razorpay subscription cancelled:', razorpaySubscriptionId)
    } catch (error: any) {
      console.error('[SubscriptionService] Razorpay cancellation error:', error)
      throw new AppError(
        'RAZORPAY_ERROR',
        error?.error?.description || 'Failed to cancel subscription with payment provider',
        500
      )
    }
  }

  /**
   * Resumes a cancelled Razorpay subscription
   *
   * Removes the cancel_at_cycle_end flag by calling cancel with 0
   */
  private async resumeRazorpaySubscription(
    razorpaySubscriptionId: string
  ): Promise<void> {
    if (!this.razorpay) {
      throw new AppError(
        'PAYMENT_SERVICE_ERROR',
        'Payment service not configured',
        500
      )
    }

    try {
      // Call cancel endpoint with 0 to remove the cancel_at_cycle_end flag
      // This is the same API used to cancel, but with 0 it resumes the subscription
      await this.razorpay.subscriptions.cancel(razorpaySubscriptionId, 0)

      console.log('[SubscriptionService] Razorpay subscription resumed:', razorpaySubscriptionId)
    } catch (error: any) {
      console.error('[SubscriptionService] Razorpay resume error:', error)
      throw new AppError(
        'RAZORPAY_ERROR',
        error?.error?.description || 'Failed to resume subscription with payment provider',
        500
      )
    }
  }

  /**
   * Fetches subscription details from Razorpay
   */
  private async fetchRazorpaySubscription(
    razorpaySubscriptionId: string
  ): Promise<RazorpaySubscriptionResponse> {
    if (!this.razorpay) {
      throw new AppError(
        'PAYMENT_SERVICE_ERROR',
        'Payment service not configured',
        500
      )
    }

    try {
      const subscription = await this.razorpay.subscriptions.fetch(
        razorpaySubscriptionId
      ) as unknown as RazorpaySubscriptionResponse

      return subscription
    } catch (error: any) {
      console.error('[SubscriptionService] Razorpay fetch error:', error)
      throw new AppError(
        'RAZORPAY_ERROR',
        error?.error?.description || 'Failed to fetch subscription from payment provider',
        500
      )
    }
  }

  /**
   * Stores subscription in database
   */
  private async storeSubscription(
    userId: string,
    razorpaySubscription: RazorpaySubscriptionResponse,
    planType: SubscriptionPlanType = 'premium'
  ): Promise<Subscription> {
    const { data, error } = await this.supabaseClient
      .from('subscriptions')
      .insert({
        user_id: userId,
        razorpay_subscription_id: razorpaySubscription.id,
        razorpay_plan_id: razorpaySubscription.plan_id,
        razorpay_customer_id: razorpaySubscription.customer_id || null,
        status: this.mapRazorpayStatus(razorpaySubscription.status),
        plan_type: `${planType}_monthly`,
        current_period_start: razorpaySubscription.current_start
          ? new Date(razorpaySubscription.current_start * 1000).toISOString()
          : null,
        current_period_end: razorpaySubscription.current_end
          ? new Date(razorpaySubscription.current_end * 1000).toISOString()
          : null,
        next_billing_at: razorpaySubscription.charge_at
          ? new Date(razorpaySubscription.charge_at * 1000).toISOString()
          : null,
        total_count: razorpaySubscription.total_count,
        paid_count: razorpaySubscription.paid_count,
        remaining_count: razorpaySubscription.remaining_count,
        amount_paise: this.config.amountPaise,
        currency: this.config.currency
      })
      .select()
      .single() as { data: Subscription | null, error: PostgrestError | null }

    if (error || !data) {
      console.error('[SubscriptionService] Failed to store subscription:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to store subscription',
        500
      )
    }

    return data
  }

  /**
   * Updates subscription status in database
   */
  private async updateSubscriptionStatus(
    subscriptionId: string,
    status: SubscriptionStatus,
    additionalFields?: Partial<Subscription>
  ): Promise<Subscription> {
    const { data, error } = await this.supabaseClient
      .from('subscriptions')
      .update({
        status,
        ...additionalFields
      })
      .eq('id', subscriptionId)
      .select()
      .single() as { data: Subscription | null, error: PostgrestError | null }

    if (error || !data) {
      console.error('[SubscriptionService] Failed to update subscription:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to update subscription',
        500
      )
    }

    return data
  }

  /**
   * Updates subscription from Razorpay data
   */
  private async updateSubscriptionFromRazorpay(
    subscriptionId: string,
    userId: string,
    razorpaySubscription: RazorpaySubscriptionResponse
  ): Promise<Subscription> {
    const newStatus = this.mapRazorpayStatus(razorpaySubscription.status)

    const { data, error } = await this.supabaseClient
      .from('subscriptions')
      .update({
        status: newStatus,
        current_period_start: razorpaySubscription.current_start
          ? new Date(razorpaySubscription.current_start * 1000).toISOString()
          : null,
        current_period_end: razorpaySubscription.current_end
          ? new Date(razorpaySubscription.current_end * 1000).toISOString()
          : null,
        next_billing_at: razorpaySubscription.charge_at
          ? new Date(razorpaySubscription.charge_at * 1000).toISOString()
          : null,
        paid_count: razorpaySubscription.paid_count,
        remaining_count: razorpaySubscription.remaining_count
      })
      .eq('id', subscriptionId)
      .select()
      .single() as { data: Subscription | null, error: PostgrestError | null }

    if (error || !data) {
      console.error('[SubscriptionService] Failed to sync subscription:', error)
      throw new AppError(
        'DATABASE_ERROR',
        'Failed to sync subscription',
        500
      )
    }

    return data
  }

  /**
   * Logs subscription event to history
   */
  private async logSubscriptionEvent(
    subscriptionId: string,
    userId: string,
    eventType: SubscriptionEventType,
    previousStatus: SubscriptionStatus | null,
    newStatus: SubscriptionStatus,
    paymentId: string | null,
    paymentAmount: number | null,
    paymentStatus: string | null,
    eventData?: Record<string, unknown>
  ): Promise<void> {
    try {
      await this.supabaseClient
        .rpc('log_subscription_event', {
          p_subscription_id: subscriptionId,
          p_user_id: userId,
          p_event_type: eventType,
          p_previous_status: previousStatus,
          p_new_status: newStatus,
          p_payment_id: paymentId,
          p_payment_amount: paymentAmount,
          p_payment_status: paymentStatus,
          p_event_data: eventData || null
        })
    } catch (error) {
      // Don't fail the operation if logging fails
      console.warn('[SubscriptionService] Failed to log event:', error)
    }
  }

  /**
   * Ensures user has no existing active subscription
   */
  private async ensureNoActiveSubscription(userId: string): Promise<void> {
    const activeSubscription = await this.getActiveSubscription(userId)

    if (activeSubscription) {
      throw new AppError(
        'SUBSCRIPTION_ALREADY_EXISTS',
        'User already has an active subscription',
        409
      )
    }
  }

  /**
   * Maps Razorpay status to database status
   */
  private mapRazorpayStatus(razorpayStatus: string): SubscriptionStatus {
    const statusMap: Record<string, SubscriptionStatus> = {
      'created': 'created',
      'authenticated': 'authenticated',
      'active': 'active',
      'paused': 'paused',
      'cancelled': 'cancelled',
      'completed': 'completed',
      'expired': 'expired',
      'halted': 'paused',
      'pending': 'created'
    }

    return statusMap[razorpayStatus] || 'created'
  }

  /**
   * Validates service configuration
   */
  private validateConfiguration(): void {
    if (!this.config.planId) {
      throw new AppError(
        'CONFIGURATION_ERROR',
        'Razorpay plan ID not configured. Set RAZORPAY_PREMIUM_PLAN_ID environment variable.',
        500
      )
    }

    if (!this.razorpay) {
      throw new AppError(
        'CONFIGURATION_ERROR',
        'Razorpay not configured. Check RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET.',
        500
      )
    }
  }
}
