/**
 * Token System Type Definitions
 *
 * Complete TypeScript interfaces for the token-based usage system.
 * These types align with the database schema and business logic from
 * the token system design document.
 */

import type { StudyMode } from '../services/llm-types.ts'

/**
 * User subscription plan types
 */
export type UserPlan = 'free' | 'standard' | 'plus' | 'premium'

/**
 * Supported languages with different token costs
 */
export type SupportedLanguage = 'en' | 'hi' | 'ml'

/**
 * Per-language, per-mode flat token costs (no multipliers)
 *
 * Costs derived from actual LLM cost data (2026-03-18 production logs):
 * - EN base = 15 tokens, HI base = 25 tokens, ML base = 30 tokens
 * - Malayalam costs more due to ~7–8× script token inefficiency vs English
 * - No-overlap constraint: max Quick (ML=15) < min Standard (EN=20) ✅
 *
 * At 2 tokens = ₹1:
 *   Quick:    EN=₹5,   HI=₹6.5, ML=₹7.5
 *   Standard: EN=₹10,  HI=₹15,  ML=₹17.5
 *   Deep:     EN=₹15,  HI=₹22,  ML=₹26
 *   Lectio:   EN=₹12,  HI=₹18,  ML=₹21
 *   Sermon:   EN=₹20,  HI=₹30,  ML=₹35
 */
export const TOKEN_COST_MAP: Record<SupportedLanguage, Record<StudyMode, number>> = {
  en: { quick: 10, standard: 20, deep: 30, lectio: 24, sermon: 40 },
  hi: { quick: 13, standard: 30, deep: 44, lectio: 36, sermon: 60 },
  ml: { quick: 15, standard: 35, deep: 52, lectio: 42, sermon: 70 },
} as const

/**
 * User token balance information
 *
 * Represents the current token state for a user, including
 * both daily allocation and purchased tokens.
 */
export interface TokenInfo {
  readonly availableTokens: number      // Current daily allocation tokens
  readonly purchasedTokens: number      // Purchased tokens that never reset  
  readonly dailyLimit: number           // Maximum tokens per day for user plan
  readonly lastReset: string            // ISO date of last daily reset
  readonly totalConsumedToday: number   // Total tokens consumed since last reset
  readonly totalTokens: number          // availableTokens + purchasedTokens
  readonly userPlan: UserPlan           // User's current plan
}

/**
 * Result of token consumption operation
 * 
 * Returned by the consume tokens operation to indicate
 * success/failure and remaining token balance.
 */
export interface TokenConsumptionResult {
  readonly success: boolean             // Whether consumption succeeded
  readonly availableTokens: number      // Remaining daily tokens
  readonly purchasedTokens: number      // Remaining purchased tokens  
  readonly dailyLimit: number           // Daily limit for user plan
  readonly totalTokens: number          // Total remaining tokens
  readonly errorMessage?: string        // Error message if success is false
}

/**
 * Request payload for token purchase
 * 
 * Used by the purchase-tokens endpoint to process
 * token purchase requests from authenticated users.
 */
export interface TokenPurchaseRequest {
  readonly token_amount: number         // Number of tokens to purchase (1-10,000)
  readonly payment_method_id?: string   // Razorpay payment method identifier (optional for order creation)
}

/**
 * Result of token purchase operation
 */
export interface TokenPurchaseResult {
  readonly success: boolean
  readonly tokens_purchased: number
  readonly cost_paid: number            // Amount in rupees
  readonly tokens_per_rupee: number     // Exchange rate (2 tokens = ₹1)
  readonly new_token_balance: TokenInfo
  readonly payment_id: string
  readonly error_message?: string
}

/**
 * Configuration for token costs per language and study mode.
 * Uses a flat costMap (no multipliers) for precise per-combination control.
 */
export interface TokenCostConfig {
  readonly costMap: Record<SupportedLanguage, Record<StudyMode, number>>
  readonly defaultCost: number          // Fallback cost for unknown language/mode
}

/**
 * Default token cost configuration (revised 2026-03-19)
 *
 * Uses TOKEN_COST_MAP — a flat per-language/per-mode table derived from
 * actual LLM cost data. See docs/analysis/token_economy_analysis.md.
 */
export const DEFAULT_TOKEN_COSTS: TokenCostConfig = {
  costMap: TOKEN_COST_MAP,
  defaultCost: 20 // Fallback (EN Standard equivalent)
} as const

/**
 * User plan configuration
 * 
 * Defines daily token limits and characteristics
 * for each subscription plan type.
 */
export interface UserPlanConfig {
  readonly dailyLimit: number
  readonly isUnlimited: boolean
  readonly canPurchaseTokens: boolean
  readonly description: string
}

/**
 * Default user plan configurations (revised 2026-03-19)
 *
 * Daily token allocations sized to cover at least 1 generation per day:
 * - Free: 15 tokens (= 1 Quick in any language; ML Quick = 15 exactly)
 * - Standard: 40 tokens (= 1 Standard any language; ML Standard = 35 fits)
 * - Plus: 60 tokens (= 1 Deep any language; ML Deep = 52 fits with 8 spare)
 * - Premium: Unlimited (avg ~1,500 tokens/month fresh usage)
 */
export const DEFAULT_PLAN_CONFIGS: Record<UserPlan, UserPlanConfig> = {
  free: {
    dailyLimit: 15,
    isUnlimited: false,
    canPurchaseTokens: true,
    description: 'Free plan — 15 daily tokens (1 Quick in any language)'
  },
  standard: {
    dailyLimit: 40,
    isUnlimited: false,
    canPurchaseTokens: true,
    description: 'Standard plan — 40 daily tokens (1 Standard in any language)'
  },
  plus: {
    dailyLimit: 60,
    isUnlimited: false,
    canPurchaseTokens: true,
    description: 'Plus plan — 60 daily tokens (1 Deep in any language)'
  },
  premium: {
    dailyLimit: 999999999,       // Effectively unlimited
    isUnlimited: true,
    canPurchaseTokens: false,
    description: 'Premium — unlimited tokens (avg ~1,500/month fresh)'
  }
} as const

/**
 * Token event types for analytics tracking
 * 
 * Used by the analytics system to track all token-related
 * operations for insights and monitoring.
 */
export type TokenEventType = 
  | 'token_consumed'          // When tokens are used for operations
  | 'token_added'             // When purchased tokens are added
  | 'token_add_failed'        // When token addition fails
  | 'token_insufficient'      // When user tries operation without enough tokens
  | 'token_balance_check'     // When user checks token status
  | 'token_purchase_failed'   // When token purchase fails
  | 'token_purchase_success'  // When token purchase succeeds
  | 'token_reset'             // When daily tokens are reset

/**
 * Analytics event data structure for token operations
 * 
 * Structured data logged with each token event for
 * comprehensive tracking and analysis.
 */
export interface TokenAnalyticsData {
  readonly user_plan: UserPlan
  readonly token_cost?: number
  readonly purchased_tokens_used?: number
  readonly daily_tokens_used?: number
  readonly daily_reset?: boolean
  readonly remaining_purchased?: number
  readonly remaining_daily?: number
  readonly tokens_added?: number
  readonly source?: 'purchase' | 'admin' | 'promotion'
  readonly new_purchased_balance?: number
  readonly premium_usage?: boolean
  readonly tokens_consumed?: number
  readonly error?: string
  readonly payment_id?: string
  readonly cost_in_paise?: number
}

/**
 * Token service configuration options
 */
export interface TokenServiceConfig {
  readonly tokenCosts: TokenCostConfig
  readonly planConfigs: Record<UserPlan, UserPlanConfig>
  readonly purchaseConfig: {
    readonly tokensPerRupee: number     // 2 tokens = ₹1 (₹0.50/token)
    readonly minPurchase: number        // Minimum tokens purchasable
    readonly maxPurchase: number        // Maximum tokens purchasable
  }
}

/**
 * Default token service configuration
 */
export const DEFAULT_TOKEN_SERVICE_CONFIG: TokenServiceConfig = {
  tokenCosts: DEFAULT_TOKEN_COSTS,
  planConfigs: DEFAULT_PLAN_CONFIGS,
  purchaseConfig: {
    tokensPerRupee: 2,
    minPurchase: 1,
    maxPurchase: 10000
  }
} as const

/**
 * Helper type for database function results
 * 
 * Matches the return type structure from PostgreSQL functions
 * in the token system database schema.
 */
export interface DatabaseTokenResult {
  readonly success: boolean
  readonly available_tokens: number
  readonly purchased_tokens: number
  readonly daily_limit: number
  readonly daily_tokens_used: number
  readonly purchased_tokens_used: number
  readonly error_message?: string
}

/**
 * Database response for get_or_create_user_tokens function
 * 
 * Matches the return structure from the get_or_create_user_tokens
 * PostgreSQL function in the token system schema.
 */
export interface DatabaseUserTokensResult {
  readonly available_tokens: number
  readonly purchased_tokens: number
  readonly daily_limit: number
  readonly last_reset: string
  readonly total_consumed_today: number
}

/**
 * Database response for add_purchased_tokens function
 * Matches the exact return shape from the SQL function
 */
export interface DatabasePurchaseResult {
  readonly success: boolean
  readonly new_balance: number
  readonly error_message?: string
}

/**
 * Database response for get_token_price function
 * Matches the return shape from the pricing package lookup
 */
export interface DatabasePricingResult {
  readonly base_price: number
  readonly discounted_price: number
  readonly discount_percentage: number
}

/**
 * Database function parameters
 * 
 * Parameter types for calling the PostgreSQL token functions
 * created in Phase 1 of the implementation.
 */
export interface DatabaseTokenParams {
  readonly p_identifier: string        // User ID or session ID
  readonly p_user_plan: UserPlan       // User's subscription plan
  readonly p_token_cost?: number       // Cost for consumption operations
  readonly p_token_amount?: number     // Amount for purchase operations
}

/**
 * Token validation result
 * 
 * Result of validating token operation parameters
 * before executing database operations.
 */
export interface TokenValidationResult {
  readonly isValid: boolean
  readonly errors: string[]
  readonly warnings?: string[]
}

/**
 * Token operation context
 *
 * Context information for token operations, used for
 * analytics and audit logging.
 */
export interface TokenOperationContext {
  readonly userId?: string             // For authenticated users
  readonly sessionId?: string          // For anonymous users
  readonly userPlan: UserPlan
  readonly operation: 'consume' | 'purchase' | 'check'
  readonly language?: SupportedLanguage
  readonly ipAddress?: string
  readonly userAgent?: string
  readonly timestamp: Date

  // Usage history context (added for detailed consumption tracking)
  readonly featureName?: string        // 'study_generate', 'continue_learning', 'study_followup'
  readonly operationType?: string      // 'study_generation', 'follow_up_question'
  readonly studyMode?: StudyMode       // 'quick', 'standard', 'deep', 'lectio', 'sermon'
  readonly contentTitle?: string       // User-friendly title (e.g., 'John 3:16 Study')
  readonly contentReference?: string   // Scripture ref, topic name, or question text
  readonly inputType?: 'scripture' | 'topic' | 'question'  // Type of user input
}