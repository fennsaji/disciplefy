/**
 * Token Service
 * 
 * Centralized service for all token-based usage operations.
 * Replaces the rate limiting system with a flexible token-based approach
 * that supports different user plans and purchased tokens.
 * 
 * This service provides atomic token operations using database functions
 * created in Phase 1, ensuring data consistency and preventing race conditions.
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AppError } from '../utils/error-handler.ts'
import { 
  UserPlan, 
  SupportedLanguage,
  TokenInfo, 
  TokenConsumptionResult, 
  TokenPurchaseResult,
  TokenServiceConfig,
  TokenCostConfig,
  TokenAnalyticsData,
  TokenEventType,
  TokenValidationResult,
  TokenOperationContext,
  DatabaseTokenResult,
  DatabaseUserTokensResult,
  DatabasePurchaseResult,
  DEFAULT_TOKEN_SERVICE_CONFIG,
  DEFAULT_TOKEN_COSTS
} from '../types/token-types.ts'

/**
 * TokenService implementation
 * 
 * This service encapsulates all token-related operations and integrates
 * with the database functions created in Phase 1 of the token system.
 */
export class TokenService {
  private readonly config: TokenServiceConfig

  /**
   * Creates a new TokenService instance
   * 
   * @param supabaseClient - Configured Supabase client with service role access
   * @param config - Optional token service configuration (uses defaults if not provided)
   */
  constructor(
    private readonly supabaseClient: SupabaseClient,
    config?: Partial<TokenServiceConfig>
  ) {
    this.config = {
      ...DEFAULT_TOKEN_SERVICE_CONFIG,
      ...config
    }
  }

  /**
   * Gets the current token balance for a user
   * 
   * This method retrieves the user's token information including daily
   * allocation tokens, purchased tokens, and plan details. Automatically
   * handles daily reset if needed.
   * 
   * @param identifier - User ID for authenticated users, session ID for anonymous
   * @param userPlan - User's subscription plan
   * @returns Promise resolving to current token information
   * @throws AppError when database operation fails
   */
  async getUserTokens(identifier: string, userPlan: UserPlan): Promise<TokenInfo> {
    this.validateIdentifier(identifier)
    this.validateUserPlan(userPlan)

    try {
      const { data, error } = await this.supabaseClient
        .rpc('get_or_create_user_tokens', {
          p_identifier: identifier,
          p_user_plan: userPlan
        })
        .single() as { data: DatabaseUserTokensResult | null, error: any }

      if (error) {
        console.error('[TokenService] Failed to get user tokens:', error)
        throw new AppError(
          'TOKEN_SERVICE_ERROR', 
          'Failed to retrieve token information', 
          500
        )
      }

      if (!data) {
        throw new AppError(
          'TOKEN_SERVICE_ERROR',
          'No token data returned from database',
          500
        )
      }

      // Transform database result to TokenInfo interface
      const tokenInfo: TokenInfo = {
        availableTokens: data.available_tokens,
        purchasedTokens: data.purchased_tokens,
        dailyLimit: data.daily_limit,
        lastReset: data.last_reset,
        totalConsumedToday: data.total_consumed_today,
        totalTokens: data.available_tokens + data.purchased_tokens,
        userPlan: userPlan
      }

      return tokenInfo

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      
      console.error('[TokenService] Unexpected error getting user tokens:', error)
      throw new AppError(
        'TOKEN_SERVICE_ERROR',
        'Unexpected error retrieving token information',
        500
      )
    }
  }

  /**
   * Consumes tokens for an operation
   * 
   * Atomically checks if user has sufficient tokens and consumes them.
   * Handles purchased token priority (consumed first) and premium user
   * unlimited access. Logs analytics events for tracking.
   * 
   * @param identifier - User ID or session ID
   * @param userPlan - User's subscription plan  
   * @param tokenCost - Number of tokens to consume
   * @param context - Operation context for analytics
   * @returns Promise resolving to consumption result
   * @throws AppError when insufficient tokens or operation fails
   */
  async consumeTokens(
    identifier: string, 
    userPlan: UserPlan, 
    tokenCost: number,
    context?: Partial<TokenOperationContext>
  ): Promise<TokenConsumptionResult> {
    
    this.validateIdentifier(identifier)
    this.validateUserPlan(userPlan)
    this.validateTokenCost(tokenCost)

    try {
      const { data, error } = await this.supabaseClient
        .rpc('consume_user_tokens', {
          p_identifier: identifier,
          p_user_plan: userPlan,
          p_token_cost: tokenCost
        })
        .single() as { data: DatabaseTokenResult | null, error: any }

      if (error) {
        console.error('[TokenService] Failed to consume tokens:', error)
        throw new AppError(
          'TOKEN_SERVICE_ERROR',
          'Failed to process token consumption',
          500
        )
      }

      if (!data) {
        throw new AppError(
          'TOKEN_SERVICE_ERROR',
          'No result returned from token consumption',
          500
        )
      }

      const result: TokenConsumptionResult = {
        success: data.success,
        availableTokens: data.available_tokens,
        purchasedTokens: data.purchased_tokens,
        dailyLimit: data.daily_limit,
        totalTokens: data.available_tokens + data.purchased_tokens,
        errorMessage: data.error_message
      }

      // If consumption failed, throw appropriate error
      if (!data.success) {
        throw new AppError(
          'INSUFFICIENT_TOKENS',
          data.error_message || 'Not enough tokens available',
          429
        )
      }

      // Log successful consumption for analytics (optional since DB function also logs)
      if (context) {
        await this.logTokenAnalytics(
          identifier,
          'token_consumed',
          {
            user_plan: userPlan,
            token_cost: tokenCost,
            remaining_daily: data.available_tokens,
            remaining_purchased: data.purchased_tokens
          },
          context
        )
      }

      return result

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      
      console.error('[TokenService] Unexpected error consuming tokens:', error)
      throw new AppError(
        'TOKEN_SERVICE_ERROR',
        'Unexpected error during token consumption',
        500
      )
    }
  }

  /**
   * Adds purchased tokens to a user's account
   * 
   * Adds tokens that never reset to the user's purchased token balance.
   * Only available for authenticated users on standard plan.
   * 
   * @param identifier - User ID (must be authenticated user)
   * @param userPlan - User's subscription plan
   * @param tokenAmount - Number of tokens to add
   * @param context - Operation context for analytics
   * @returns Promise resolving to purchase result
   * @throws AppError when operation fails or user cannot purchase tokens
   */
  async addPurchasedTokens(
    identifier: string,
    userPlan: UserPlan,
    tokenAmount: number,
    context?: Partial<TokenOperationContext>
  ): Promise<{ success: boolean; newPurchasedBalance: number }> {
    
    this.validateIdentifier(identifier)
    this.validateUserPlan(userPlan)
    this.validatePurchaseAmount(tokenAmount)

    // Only standard plan users can purchase tokens
    if (userPlan !== 'standard') {
      throw new AppError(
        'INVALID_OPERATION',
        `${userPlan} plan users cannot purchase tokens`,
        400
      )
    }

    try {
      const { data, error } = await this.supabaseClient
        .rpc('add_purchased_tokens', {
          p_identifier: identifier,
          p_user_plan: userPlan,
          p_token_amount: tokenAmount
        })
        .single() as { data: DatabasePurchaseResult | null, error: any }

      if (error) {
        console.error('[TokenService] Failed to add purchased tokens:', error)
        throw new AppError(
          'TOKEN_SERVICE_ERROR',
          'Failed to add purchased tokens',
          500
        )
      }

      if (!data) {
        throw new AppError(
          'TOKEN_SERVICE_ERROR',
          'No result returned from token purchase',
          500
        )
      }

      if (!data.success) {
        throw new AppError(
          'TOKEN_PURCHASE_ERROR',
          data.error_message || 'Failed to purchase tokens',
          400
        )
      }

      // Log successful purchase for analytics (optional since DB function also logs)
      if (context) {
        await this.logTokenAnalytics(
          identifier,
          'token_added',
          {
            user_plan: userPlan,
            tokens_added: tokenAmount,
            source: 'purchase',
            new_purchased_balance: data.new_purchased_balance
          },
          context
        )
      }

      return {
        success: true,
        newPurchasedBalance: data.new_purchased_balance
      }

    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      
      console.error('[TokenService] Unexpected error adding purchased tokens:', error)
      throw new AppError(
        'TOKEN_SERVICE_ERROR',
        'Unexpected error during token purchase',
        500
      )
    }
  }

  /**
   * Calculates token cost for a language
   * 
   * Returns the number of tokens required for generating content
   * in the specified language based on complexity and model requirements.
   * 
   * @param language - Target language code
   * @returns Number of tokens required
   */
  calculateTokenCost(language: SupportedLanguage | string): number {
    const languageCode = language as SupportedLanguage
    
    if (languageCode in this.config.tokenCosts.costs) {
      return this.config.tokenCosts.costs[languageCode]
    }
    
    // Return default cost for unknown languages
    return this.config.tokenCosts.defaultCost
  }

  /**
   * Calculates cost in rupees for token amount
   * 
   * @param tokenAmount - Number of tokens
   * @returns Cost in rupees (10 tokens = ₹1)
   */
  calculateCostInRupees(tokenAmount: number): number {
    return Math.ceil(tokenAmount / this.config.purchaseConfig.tokensPerRupee)
  }

  /**
   * Gets the daily token limit for a user plan
   * 
   * @param userPlan - User's subscription plan
   * @returns Daily token limit
   */
  getDailyLimit(userPlan: UserPlan): number {
    return this.config.planConfigs[userPlan].dailyLimit
  }

  /**
   * Checks if a user plan allows token purchases
   * 
   * @param userPlan - User's subscription plan
   * @returns Whether the plan allows purchasing tokens
   */
  canPurchaseTokens(userPlan: UserPlan): boolean {
    return this.config.planConfigs[userPlan].canPurchaseTokens
  }

  /**
   * Checks if a user plan has unlimited tokens
   * 
   * @param userPlan - User's subscription plan
   * @returns Whether the plan has unlimited tokens
   */
  isUnlimitedPlan(userPlan: UserPlan): boolean {
    return this.config.planConfigs[userPlan].isUnlimited
  }

  /**
   * Validates user identifier
   * 
   * @param identifier - User or session ID to validate
   * @throws AppError for invalid identifiers
   */
  private validateIdentifier(identifier: string): void {
    if (!identifier || typeof identifier !== 'string' || identifier.trim().length === 0) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Invalid user identifier provided',
        400
      )
    }
  }

  /**
   * Validates user plan
   * 
   * @param userPlan - User plan to validate
   * @throws AppError for invalid plans
   */
  private validateUserPlan(userPlan: UserPlan): void {
    if (!['free', 'standard', 'premium'].includes(userPlan)) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Invalid user plan provided',
        400
      )
    }
  }

  /**
   * Validates token cost amount
   * 
   * @param tokenCost - Token cost to validate
   * @throws AppError for invalid amounts
   */
  private validateTokenCost(tokenCost: number): void {
    if (!Number.isInteger(tokenCost) || tokenCost <= 0 || tokenCost > 1000) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Token cost must be a positive integer between 1 and 1000',
        400
      )
    }
  }

  /**
   * Validates token purchase amount
   * 
   * @param tokenAmount - Amount to validate
   * @throws AppError for invalid amounts
   */
  private validatePurchaseAmount(tokenAmount: number): void {
    const { minPurchase, maxPurchase } = this.config.purchaseConfig
    
    if (!Number.isInteger(tokenAmount) || tokenAmount < minPurchase || tokenAmount > maxPurchase) {
      throw new AppError(
        'VALIDATION_ERROR',
        `Token purchase amount must be between ${minPurchase} and ${maxPurchase}`,
        400
      )
    }
  }

  /**
   * Logs token analytics events
   * 
   * @param identifier - User or session identifier
   * @param eventType - Type of token event
   * @param data - Analytics data
   * @param context - Operation context
   */
  private async logTokenAnalytics(
    identifier: string,
    eventType: TokenEventType,
    data: TokenAnalyticsData,
    context: Partial<TokenOperationContext>
  ): Promise<void> {
    try {
      // This uses the log_token_event function which handles analytics logging
      // The function is designed to not fail the main operation if logging fails
      await this.supabaseClient
        .rpc('log_token_event', {
          p_user_id: identifier,
          p_event_type: eventType,
          p_event_data: data,
          p_session_id: context.sessionId || null
        })
    } catch (error) {
      // Log error but don't fail the main operation
      console.warn('[TokenService] Failed to log analytics event:', error)
    }
  }
}