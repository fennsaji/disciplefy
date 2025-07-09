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
const DEFAULT_ANONYMOUS_LIMIT = 3 as const
const DEFAULT_AUTHENTICATED_LIMIT = 30 as const
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

      if (userType === 'anonymous') {
        await this.recordAnonymousUsage(identifier)
      } else {
        // For authenticated users, usage is tracked by the study_guides table
        // No additional recording needed
      }
    } catch (error) {
      console.error('Failed to record usage:', error)
      // Don't fail the request if usage recording fails
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

      if (userType === 'anonymous') {
        await this.resetAnonymousLimit(identifier)
      } else {
        // For authenticated users, we would need to delete recent study guides
        // This should only be done by admin operations
        console.warn('Resetting authenticated user limits is not implemented')
      }
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
    const { count } = await this.supabaseClient
      .from('anonymous_study_guides')
      .select('*', { count: 'exact', head: true })
      .eq('session_id', sessionId)
      .gte('created_at', windowStart.toISOString())

    return count ?? 0
  }

  /**
   * Gets usage count for authenticated users.
   * 
   * @param userId - User ID
   * @param windowStart - Start of time window
   * @returns Promise resolving to usage count
   */
  private async getAuthenticatedUsage(userId: string, windowStart: Date): Promise<number> {
    const { count } = await this.supabaseClient
      .from('study_guides')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .gte('created_at', windowStart.toISOString())

    return count ?? 0
  }

  /**
   * Records usage for anonymous users.
   * 
   * @param sessionId - Anonymous session ID
   */
  private async recordAnonymousUsage(sessionId: string): Promise<void> {
    const currentCount = await this.getCurrentUsage(sessionId, 'anonymous')
    
    await this.supabaseClient
      .from('anonymous_sessions')
      .update({
        study_guides_count: currentCount + 1,
        last_activity: new Date().toISOString()
      })
      .eq('session_id', sessionId)
  }

  /**
   * Resets rate limit for anonymous users.
   * 
   * @param sessionId - Anonymous session ID
   */
  private async resetAnonymousLimit(sessionId: string): Promise<void> {
    await this.supabaseClient
      .from('anonymous_sessions')
      .update({ study_guides_count: 0 })
      .eq('session_id', sessionId)
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