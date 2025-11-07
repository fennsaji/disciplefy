/**
 * Subscription Type Definitions
 *
 * TypeScript interfaces and types for Razorpay premium subscription system.
 * These types ensure type safety across subscription-related operations.
 */

/**
 * Subscription status values matching database CHECK constraint
 */
export type SubscriptionStatus =
  | 'created'               // Initial state after Razorpay subscription creation
  | 'authenticated'         // User authorized recurring payments
  | 'active'                // Currently active and billing
  | 'pending_cancellation'  // Scheduled to cancel at cycle end, still active with premium access
  | 'paused'                // Temporarily paused (payment failure or admin action)
  | 'cancelled'             // Cancelled and ended (no longer active)
  | 'completed'             // Reached total_count cycles
  | 'expired'               // Grace period ended after cancellation

/**
 * Subscription event types matching database CHECK constraint
 */
export type SubscriptionEventType =
  | 'subscription.created'
  | 'subscription.authenticated'
  | 'subscription.activated'
  | 'subscription.charged'
  | 'subscription.cancelled'
  | 'subscription.paused'
  | 'subscription.resumed'
  | 'subscription.completed'
  | 'subscription.pending'
  | 'subscription.updated'

/**
 * Invoice status values matching database CHECK constraint
 */
export type InvoiceStatus =
  | 'paid'
  | 'failed'
  | 'pending'
  | 'refunded'

/**
 * Subscription database row interface
 */
export interface Subscription {
  readonly id: string
  readonly user_id: string
  readonly razorpay_subscription_id: string
  readonly razorpay_plan_id: string
  readonly razorpay_customer_id: string | null
  readonly status: SubscriptionStatus
  readonly plan_type: string
  readonly current_period_start: string | null
  readonly current_period_end: string | null
  readonly next_billing_at: string | null
  readonly total_count: number | null  // null = unlimited subscription
  readonly paid_count: number
  readonly remaining_count: number
  readonly amount_paise: number
  readonly currency: string
  readonly cancelled_at: string | null
  readonly cancel_at_cycle_end: boolean
  readonly cancellation_reason: string | null
  readonly created_at: string
  readonly updated_at: string
}

/**
 * Subscription history database row interface
 */
export interface SubscriptionHistory {
  readonly id: string
  readonly subscription_id: string
  readonly user_id: string
  readonly event_type: SubscriptionEventType
  readonly previous_status: SubscriptionStatus | null
  readonly new_status: SubscriptionStatus
  readonly payment_id: string | null
  readonly payment_amount: number | null
  readonly payment_status: string | null
  readonly event_data: Record<string, unknown> | null
  readonly notes: string | null
  readonly created_at: string
}

/**
 * Subscription invoice database row interface
 */
export interface SubscriptionInvoice {
  readonly id: string
  readonly subscription_id: string
  readonly user_id: string
  readonly razorpay_payment_id: string
  readonly razorpay_invoice_id: string | null
  readonly invoice_number: string
  readonly amount_paise: number
  readonly currency: string
  readonly billing_period_start: string
  readonly billing_period_end: string
  readonly status: InvoiceStatus
  readonly payment_method: string | null
  readonly paid_at: string | null
  readonly created_at: string
  readonly updated_at: string
}

/**
 * Razorpay API subscription creation response
 */
export interface RazorpaySubscriptionResponse {
  readonly id: string
  readonly entity: 'subscription'
  readonly plan_id: string
  readonly customer_id?: string
  readonly status: string
  readonly current_start: number | null
  readonly current_end: number | null
  readonly ended_at: number | null
  readonly quantity: number
  readonly notes: Record<string, string>
  readonly charge_at: number
  readonly start_at: number | null
  readonly end_at: number | null
  readonly auth_attempts: number
  readonly total_count: number | null  // null = unlimited subscription
  readonly paid_count: number
  readonly customer_notify: 0 | 1
  readonly created_at: number
  readonly expire_by: number | null
  readonly expired_at: number | null
  readonly has_scheduled_changes: boolean
  readonly change_scheduled_at: number | null
  readonly short_url: string
  readonly remaining_count: number
}

/**
 * Razorpay webhook event for subscriptions
 */
export interface RazorpaySubscriptionWebhook {
  readonly entity: 'event'
  readonly account_id: string
  readonly event: SubscriptionEventType
  readonly contains: string[]
  readonly payload: {
    readonly subscription: {
      readonly entity: RazorpaySubscriptionResponse
    }
    readonly payment?: {
      readonly entity: {
        readonly id: string
        readonly entity: 'payment'
        readonly amount: number
        readonly currency: string
        readonly status: string
        readonly order_id: string | null
        readonly invoice_id: string | null
        readonly method: string
        readonly captured: boolean
        readonly email: string | null
        readonly contact: string | null
        readonly created_at: number
      }
    }
  }
  readonly created_at: number
}

/**
 * Subscription creation request body
 * Note: Empty type as no body is needed - user authenticated via JWT
 * and plan ID comes from environment variable
 */
export type CreateSubscriptionRequest = Record<string, never>

/**
 * Subscription creation response
 */
export interface CreateSubscriptionResponse {
  readonly success: boolean
  readonly subscription_id: string
  readonly razorpay_subscription_id: string
  readonly short_url: string
  readonly amount_rupees: number
  readonly status: SubscriptionStatus
  readonly message: string
}

/**
 * Cancel subscription request body
 */
export interface CancelSubscriptionRequest {
  readonly cancel_at_cycle_end: boolean  // true = cancel at period end, false = cancel immediately
  readonly reason?: string                // Optional cancellation reason
}

/**
 * Cancel subscription response
 */
export interface CancelSubscriptionResponse {
  readonly success: boolean
  readonly subscription_id: string
  readonly status: SubscriptionStatus
  readonly cancelled_at: string
  readonly active_until: string | null  // If cancel_at_cycle_end = true
  readonly message: string
}

/**
 * Get subscription status response
 */
export interface GetSubscriptionResponse {
  readonly success: boolean
  readonly subscription: Subscription | null
  readonly next_billing: {
    readonly date: string | null
    readonly amount_rupees: number
  } | null
  readonly can_cancel: boolean
  readonly message?: string
}

/**
 * Database result from has_active_subscription function
 */
export interface DatabaseActiveSubscriptionResult {
  readonly has_active: boolean
}

/**
 * Database result from get_user_plan_with_subscription function
 */
export interface DatabaseUserPlanResult {
  readonly user_plan: 'free' | 'standard' | 'premium'
}

/**
 * Subscription service configuration
 */
export interface SubscriptionServiceConfig {
  readonly planId: string              // Razorpay plan ID (from environment)
  readonly amountPaise: number         // ₹100 = 10000 paise
  readonly currency: string            // 'INR'
  readonly totalCount: number | null   // null = unlimited, number = fixed cycles
  readonly customerNotify: 0 | 1       // 1 = send customer notifications
}

/**
 * Default subscription configuration
 */
export const DEFAULT_SUBSCRIPTION_CONFIG: SubscriptionServiceConfig = {
  planId: '',  // Set from RAZORPAY_PREMIUM_PLAN_ID env var
  amountPaise: 10000,  // ₹100
  currency: 'INR',
  totalCount: null,    // ✅ Unlimited subscription (no end date)
  customerNotify: 1    // Send notifications
}

/**
 * Subscription creation options
 */
export interface CreateSubscriptionOptions {
  readonly userId: string
  readonly startAt?: number  // Unix timestamp for subscription start
  readonly notes?: Record<string, string>
}

/**
 * Subscription cancellation options
 */
export interface CancelSubscriptionOptions {
  readonly userId: string
  readonly subscriptionId: string
  readonly cancelAtCycleEnd: boolean
  readonly reason?: string
}
