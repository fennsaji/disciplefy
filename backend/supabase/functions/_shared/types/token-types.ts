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
 * Mode-based token cost multipliers
 * Applied to base language cost to support premium/expensive modes
 */
export interface TokenCostMultiplier {
  readonly quick: number
  readonly standard: number
  readonly deep: number
  readonly lectio: number
  readonly sermon: number
}

/**
 * Default mode multipliers for token costs
 *
 * Multipliers based on study duration and complexity:
 * - Quick (3 min): 0.5x - Brief overview, minimal depth
 * - Standard (10 min): 1.0x - Baseline, moderate content
 * - Deep Dive (25 min): 1.5x - Extensive word studies, cross-references
 * - Lectio Divina (15 min): 1.2x - Contemplative + guided reflection
 * - Sermon (55 min): 2.0x - Most comprehensive content, all languages
 *
 * Multipliers are applied uniformly across languages.
 * Varying final costs result from different base language costs (EN=10, HI/ML=15).
 * Final costs: Quick=5/8, Standard=10/15, Deep=15/23, Lectio=12/18, Sermon=20/30 (EN/HI,ML)
 */
export const MODE_MULTIPLIERS: TokenCostMultiplier = {
  quick: 0.5,      // Half cost - encourages quick studies
  standard: 1.0,   // Baseline - no change
  deep: 1.5,       // Premium content - 50% more
  lectio: 1.2,     // Moderate premium - 20% more
  sermon: 2.0      // Most expensive - 2x for all languages
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
  readonly tokens_per_rupee: number     // Exchange rate (4 tokens = ₹1)
  readonly new_token_balance: TokenInfo
  readonly payment_id: string
  readonly error_message?: string
}

/**
 * Configuration for language-based token costs
 *
 * Defines how many tokens each language costs for
 * study guide generation operations, including mode-based multipliers.
 */
export interface TokenCostConfig {
  readonly costs: Record<SupportedLanguage, number>
  readonly modeMultipliers: TokenCostMultiplier
  readonly defaultCost: number          // Fallback cost for unknown languages
}

/**
 * Default token cost configuration
 *
 * Based on LLM complexity and language processing requirements:
 * - English: 10 tokens base (simpler, well-supported)
 * - Hindi/Malayalam: 15 tokens base (moderate complexity, specialized models)
 *
 * Mode multipliers are applied uniformly across all languages:
 * - Quick: 0.5x, Standard: 1.0x, Deep: 1.5x, Lectio: 1.2x, Sermon: 2.0x
 * - Example costs: EN Quick=5, Standard=10, Sermon=20
 *                  HI/ML Quick=8, Standard=15, Sermon=30
 */
export const DEFAULT_TOKEN_COSTS: TokenCostConfig = {
  costs: {
    'en': 10,    // English
    'hi': 15,    // Hindi (reduced from 20)
    'ml': 15     // Malayalam (reduced from 20)
  },
  modeMultipliers: MODE_MULTIPLIERS,
  defaultCost: 10 // Default to English cost
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
 * Default user plan configurations
 *
 * Defines the token allocation and features for each plan:
 * - Free: 8 tokens daily (anonymous users)
 * - Standard: 20 tokens daily (authenticated users)
 * - Plus: 50 tokens daily (subscription users)
 * - Premium: Unlimited tokens (admin/subscription users)
 */
export const DEFAULT_PLAN_CONFIGS: Record<UserPlan, UserPlanConfig> = {
  free: {
    dailyLimit: 8,
    isUnlimited: false,
    canPurchaseTokens: true,     // Free authenticated users can purchase tokens
    description: 'Free plan users with 8 daily tokens'
  },
  standard: {
    dailyLimit: 20,
    isUnlimited: false,
    canPurchaseTokens: true,     // Can purchase additional tokens
    description: 'Authenticated users with 20 daily tokens + purchase option'
  },
  plus: {
    dailyLimit: 50,
    isUnlimited: false,
    canPurchaseTokens: true,     // Can purchase additional tokens
    description: 'Plus plan users with 50 daily tokens + purchase option'
  },
  premium: {
    dailyLimit: 999999999,       // Effectively unlimited
    isUnlimited: true,
    canPurchaseTokens: false,    // No need to purchase tokens
    description: 'Unlimited access for admin and subscription users'
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
    readonly tokensPerRupee: number     // 4 tokens = ₹1
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
    tokensPerRupee: 4,
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
  readonly new_purchased_balance: number
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