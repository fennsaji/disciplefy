import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AppError } from './error-handler.ts'

/**
 * Rate limit check result.
 */
interface RateLimitResult {
  readonly allowed: boolean
  readonly remaining: number
  readonly resetTime: number
  readonly currentUsage: number
  readonly limit: number
}

/**
 * Configuration for rate limiting rules.
 */
interface RateLimitConfig {
  readonly anonymousLimit: number
  readonly authenticatedLimit: number
  readonly windowMinutes: number
}

/**
 * User type enumeration for rate limiting.
 */
type UserType = 'anonymous' | 'authenticated'

// Default configuration constants
const DEFAULT_ANONYMOUS_LIMIT = 1 as const
const DEFAULT_AUTHENTICATED_LIMIT = 5 as const
const DEFAULT_WINDOW_MINUTES = 60 as const

/**
 * Rate limiter for Edge Functions.
 * 
 * Provides configurable rate limiting with different limits for
 * anonymous and authenticated users. Follows fail-open principle
 * to avoid blocking users during database issues.
 */
export class RateLimiter {
  private readonly config: RateLimitConfig

  /**
   * Creates a new rate limiter instance.
   * 
   * @param supabaseClient - Configured Supabase client
   * @param config - Optional rate limiting configuration
   */
  constructor(
    private readonly supabaseClient: SupabaseClient,
    config?: Partial<RateLimitConfig>
  ) {
    this.config = {
      anonymousLimit: config?.anonymousLimit ?? DEFAULT_ANONYMOUS_LIMIT,
      authenticatedLimit: config?.authenticatedLimit ?? DEFAULT_AUTHENTICATED_LIMIT,
      windowMinutes: config?.windowMinutes ?? DEFAULT_WINDOW_MINUTES
    }
  }

  /**
   * Checks if a user has exceeded their rate limit.
   * 
   * This method follows the fail-open principle: if there's an error
   * checking the rate limit (e.g., database issues), it allows the request
   * to proceed rather than blocking the user.
   * 
   * @param identifier - User identifier (user ID or session ID)
   * @param userType - Type of user (anonymous or authenticated)
   * @returns Promise resolving to rate limit check result
   */
  async checkRateLimit(identifier: string, userType: UserType): Promise<RateLimitResult> {
    try {
      this.validateInputs(identifier, userType)

      const limit = this.getLimitForUserType(userType)
      const windowStart = this.calculateWindowStart()
      const currentUsage = await this.getCurrentUsage(identifier, userType, windowStart)
      
      const remaining = Math.max(0, limit - currentUsage)
      const allowed = currentUsage < limit
      const resetTime = this.calculateResetTime()

      return {
        allowed,
        remaining,
        resetTime,
        currentUsage,
        limit
      }
    } catch (error) {
      console.error('Rate limiting error:', error)
      
      // Fail open: allow the request if rate limiting fails
      const limit = this.getLimitForUserType(userType)
      return {
        allowed: true,
        remaining: limit,
        resetTime: this.calculateResetTime(),
        currentUsage: 0,
        limit
      }
    }
  }

  /**
   * Records usage for rate limiting tracking.
   * 
   * Updates the usage counter for the specified user. This method
   * is called after a successful operation to track usage.
   * 
   * @param identifier - User identifier
   * @param userType - Type of user
   * @returns Promise that resolves when usage is recorded
   */
  async recordUsage(identifier: string, userType: UserType): Promise<void> {
    try {
      this.validateInputs(identifier, userType)
      
      const windowStart = this.calculateWindowStart()
      await this.incrementUsageInRateLimitTable(identifier, userType, windowStart)
    } catch (error) {
      console.error('Failed to record usage:', error)
      // Don't fail the request if usage recording fails (fail-open principle)
    }
  }

  /**
   * Enforces rate limit by throwing an error if limit is exceeded.
   * 
   * This is a convenience method that combines checking and enforcing
   * rate limits in a single call.
   * 
   * @param identifier - User identifier
   * @param userType - Type of user
   * @throws {AppError} When rate limit is exceeded
   */
  async enforceRateLimit(identifier: string, userType: UserType): Promise<void> {
    const result = await this.checkRateLimit(identifier, userType)
    
    if (!result.allowed) {
      throw new AppError(
        'RATE_LIMIT_EXCEEDED',
        `Rate limit exceeded. ${result.remaining} requests remaining. Try again in ${result.resetTime} minutes.`,
        429
      )
    }
  }

  /**
   * Resets rate limit for a specific user (admin function).
   * 
   * @param identifier - User identifier
   * @param userType - Type of user
   * @returns Promise that resolves when limit is reset
   * @throws {AppError} When reset operation fails
   */
  async resetUserLimit(identifier: string, userType: UserType): Promise<void> {
    try {
      this.validateInputs(identifier, userType)

      // Reset rate limit for both user types using the unified table
      await this.resetRateLimitInTable(identifier, userType)
    } catch (error) {
      console.error('Failed to reset user limit:', error)
      throw new AppError(
        'RATE_LIMIT_RESET_ERROR',
        'Failed to reset rate limit for user',
        500
      )
    }
  }

  /**
   * Gets the current usage count for a user within the time window.
   * 
   * @param identifier - User identifier
   * @param userType - Type of user
   * @param windowStart - Start of the time window
   * @returns Promise resolving to current usage count
   */
  private async getCurrentUsage(
    identifier: string, 
    userType: UserType, 
    windowStart?: Date
  ): Promise<number> {
    
    const effectiveWindowStart = windowStart ?? this.calculateWindowStart()

    if (userType === 'anonymous') {
      return this.getAnonymousUsage(identifier, effectiveWindowStart)
    } else {
      return this.getAuthenticatedUsage(identifier, effectiveWindowStart)
    }
  }

  /**
   * Gets usage count for anonymous users.
   * 
   * @param sessionId - Anonymous session ID
   * @param windowStart - Start of time window
   * @returns Promise resolving to usage count
   */
  private async getAnonymousUsage(sessionId: string, windowStart: Date): Promise<number> {
    return this.getUsageFromRateLimitTable(sessionId, 'anonymous', windowStart)
  }

  /**
   * Gets usage count for authenticated users.
   * 
   * @param userId - User ID
   * @param windowStart - Start of time window
   * @returns Promise resolving to usage count
   */
  private async getAuthenticatedUsage(userId: string, windowStart: Date): Promise<number> {
    return this.getUsageFromRateLimitTable(userId, 'authenticated', windowStart)
  }

  /**
   * Gets usage count from the unified rate_limit_usage table.
   * 
   * @param identifier - User identifier (user ID or session ID)
   * @param userType - Type of user
   * @param windowStart - Start of time window
   * @returns Promise resolving to usage count
   */
  private async getUsageFromRateLimitTable(
    identifier: string, 
    userType: UserType, 
    windowStart: Date
  ): Promise<number> {
    try {
      const { data, error } = await this.supabaseClient
        .from('rate_limit_usage')
        .select('count')
        .eq('identifier', identifier)
        .eq('user_type', userType)
        .eq('window_start', windowStart.toISOString())
        .single()

      if (error) {
        if (error.code === 'PGRST116') {
          // No record found - return 0
          return 0
        }
        throw error
      }

      return data?.count ?? 0
    } catch (error) {
      console.error('Error getting usage from rate limit table:', error)
      // Fail open - return 0 if we can't get the count
      return 0
    }
  }

  /**
   * Increments usage count in the unified rate_limit_usage table.
   * 
   * @param identifier - User identifier (user ID or session ID)
   * @param userType - Type of user
   * @param windowStart - Start of time window
   * @returns Promise that resolves when usage is recorded
   */
  private async incrementUsageInRateLimitTable(
    identifier: string, 
    userType: UserType, 
    windowStart: Date
  ): Promise<void> {
    try {
      // Use the PostgreSQL function for atomic increment
      const { error } = await this.supabaseClient
        .rpc('increment_rate_limit_usage', {
          p_identifier: identifier,
          p_user_type: userType,
          p_window_start: windowStart.toISOString()
        })

      if (error) {
        console.error('Failed to increment rate limit usage:', error)
        // Fail open - don't throw error to avoid blocking user
      }
    } catch (error) {
      console.error('Error incrementing usage in rate limit table:', error)
      // Fail open - don't throw error to avoid blocking user
    }
  }

  /**
   * Resets rate limit for a user in the unified rate_limit_usage table.
   * 
   * @param identifier - User identifier (user ID or session ID)
   * @param userType - Type of user
   */
  private async resetRateLimitInTable(identifier: string, userType: UserType): Promise<void> {
    try {
      await this.supabaseClient
        .from('rate_limit_usage')
        .delete()
        .eq('identifier', identifier)
        .eq('user_type', userType)
    } catch (error) {
      console.error('Failed to reset rate limit:', error)
      throw new AppError(
        'RATE_LIMIT_RESET_ERROR',
        `Failed to reset rate limit for ${userType} user`,
        500
      )
    }
  }

  /**
   * Validates input parameters.
   * 
   * @param identifier - User identifier to validate
   * @param userType - User type to validate
   * @throws {AppError} When inputs are invalid
   */
  private validateInputs(identifier: string, userType: UserType): void {
    if (!identifier || typeof identifier !== 'string') {
      throw new AppError(
        'VALIDATION_ERROR',
        'Invalid user identifier provided',
        400
      )
    }

    if (!['anonymous', 'authenticated'].includes(userType)) {
      throw new AppError(
        'VALIDATION_ERROR',
        'Invalid user type. Must be "anonymous" or "authenticated"',
        400
      )
    }
  }

  /**
   * Gets the rate limit for the specified user type.
   * 
   * @param userType - Type of user
   * @returns Rate limit for the user type
   */
  private getLimitForUserType(userType: UserType): number {
    return userType === 'anonymous' 
      ? this.config.anonymousLimit 
      : this.config.authenticatedLimit
  }

  /**
   * Calculates the start of the current time window.
   * 
   * @returns Date representing the start of the time window
   */
  private calculateWindowStart(): Date {
    const now = new Date()
    const windowStart = new Date(now)
    windowStart.setMinutes(now.getMinutes() - this.config.windowMinutes)
    return windowStart
  }

  /**
   * Calculates time until rate limit resets (in minutes).
   * 
   * @returns Minutes until the rate limit window resets
   */
  private calculateResetTime(): number {
    const now = new Date()
    const nextWindow = new Date(now)
    nextWindow.setMinutes(
      Math.ceil(now.getMinutes() / this.config.windowMinutes) * this.config.windowMinutes,
      0,
      0
    )
    
    return Math.ceil((nextWindow.getTime() - now.getTime()) / (1000 * 60))
  }
}