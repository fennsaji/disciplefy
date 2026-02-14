/**
 * Authentication Service
 * 
 * Centralized authentication logic to eliminate security vulnerabilities
 * and provide a single source of truth for user identity validation.
 * 
 * This service addresses critical security issues:
 * - Insecure JWT manual decoding without signature verification
 * - Client-provided user context allowing user impersonation
 * - Incomplete CSRF protection in OAuth flows
 */

import { SupabaseClient, createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AppError } from '../utils/error-handler.ts'
import { UserPlan } from '../types/token-types.ts'
import { UserContext } from '../types/index.ts'

/**
 * Authentication result with additional metadata
 */
export interface AuthResult {
  readonly userContext: UserContext
  readonly user: any // Raw user object from Supabase
  readonly session: any // Raw session object from Supabase
}

/**
 * User profile information from database
 */
interface UserProfile {
  readonly id: string
  readonly is_admin: boolean
  readonly language_preference?: string
  readonly theme_preference?: string
  readonly premium_trial_end_at?: string | null
  readonly has_used_premium_trial?: boolean
}

/**
 * Subscription record from database
 */
interface Subscription {
  readonly status: string
  readonly plan_type: string | null
  readonly current_period_end: string | null
  readonly cancel_at_cycle_end: boolean | null
}

/**
 * Centralized Authentication Service
 * 
 * This service is the single source of truth for user identity validation.
 * It replaces all insecure local implementations with proper JWT validation
 * through Supabase's built-in security mechanisms.
 */
export class AuthService {
  constructor(
    private readonly supabaseUrl: string,
    private readonly supabaseAnonKey: string,
    private readonly supabaseServiceClient?: SupabaseClient
  ) {}
  
  /**
   * Securely gets user context from the request's Authorization header
   * 
   * This method uses Supabase's built-in JWT validation, which:
   * - Verifies the token signature
   * - Checks token expiration
   * - Validates the token issuer
   * - Ensures token integrity
   * 
   * @param req - HTTP request containing Authorization header
   * @returns Promise resolving to verified user context
   * @throws AppError when authentication fails
   */
  async getUserContext(req: Request): Promise<UserContext> {
    const authClient = this.createAuthClient(req)
    
    try {
      const { data: { user }, error } = await authClient.auth.getUser()
      
      if (error) {
        // Handle specific error types for better error messages
        if (error.message?.includes('expired')) {
          throw new AppError('UNAUTHORIZED', 'Token has expired. Please sign in again.', 401)
        } else if (error.message?.includes('invalid')) {
          throw new AppError('UNAUTHORIZED', 'Invalid authentication token', 401)
        } else if (error.message?.includes('signature')) {
          throw new AppError('UNAUTHORIZED', 'Token signature is invalid', 401)
        } else {
          throw new AppError('UNAUTHORIZED', error.message, 401)
        }
      }
      
      if (!user) {
        throw new AppError('UNAUTHORIZED', 'No user found for the provided token.', 401)
      }
      
      // Additional validation for user object integrity
      if (!user.id || typeof user.id !== 'string') {
        throw new AppError('UNAUTHORIZED', 'Invalid user data in token', 401)
      }
      
      // For authenticated users, check if they are admin
      let userType: 'admin' | 'user' | undefined = undefined
      if (!user.is_anonymous && user.id) {
        try {
          const userProfile = await this.getUserProfile(user.id)
          userType = userProfile?.is_admin ? 'admin' : 'user'
        } catch (error) {
          // If profile lookup fails, default to regular user
          console.warn('[AuthService] Failed to fetch user profile for userType:', error)
          userType = 'user'
        }
      }
      
      // Create standardized user context
      const userContext: UserContext = {
        type: user.is_anonymous ? 'anonymous' : 'authenticated',
        userId: user.is_anonymous ? undefined : user.id,
        sessionId: user.is_anonymous ? user.id : undefined,
        userType
      }
      
      return userContext
      
    } catch (error) {
      if (error instanceof AppError) {
        throw error
      }
      
      // Handle network or other unexpected errors
      throw new AppError(
        'AUTHENTICATION_ERROR',
        `Authentication failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        401
      )
    }
  }
  
  /**
   * Gets full authentication result including user and session data
   * 
   * @param req - HTTP request containing Authorization header
   * @returns Promise resolving to complete auth result
   */
  async getAuthResult(req: Request): Promise<AuthResult> {
    const authClient = this.createAuthClient(req)
    
    const { data: { user }, error } = await authClient.auth.getUser()
    
    if (error || !user) {
      throw new AppError('UNAUTHORIZED', error?.message || 'Authentication failed', 401)
    }
    
    const userContext: UserContext = {
      type: user.is_anonymous ? 'anonymous' : 'authenticated',
      userId: user.is_anonymous ? undefined : user.id,
      sessionId: user.is_anonymous ? user.id : undefined
    }
    
    return {
      userContext,
      user,
      session: null // Session not available from getUser(), would need getSession() instead
    }
  }
  
  /**
   * Creates a Supabase client scoped to the incoming request's auth header
   * 
   * This ensures that all authentication operations use the correct token
   * and maintain proper security context.
   * 
   * @param req - HTTP request containing Authorization header
   * @returns Configured Supabase client
   */
  createAuthClient(req: Request): SupabaseClient {
    if (!this.supabaseUrl || !this.supabaseAnonKey) {
      throw new AppError(
        'CONFIGURATION_ERROR',
        'Missing required Supabase configuration',
        500
      )
    }

    // Get authorization token from header or query parameters (for EventSource)
    let authToken = req.headers.get('Authorization') || ''

    // For EventSource requests, check query parameters as fallback
    if (!authToken) {
      const url = new URL(req.url)
      const queryAuthToken = url.searchParams.get('authorization')
      if (queryAuthToken) {
        authToken = `Bearer ${queryAuthToken}`
      }
    }

    return createClient(this.supabaseUrl, this.supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authToken
        }
      }
    })
  }
  
  /**
   * Validates OAuth state parameter for CSRF protection
   * 
   * This method properly validates the state parameter against server-stored values
   * to prevent Cross-Site Request Forgery attacks.
   * 
   * @param state - State parameter from OAuth callback
   * @param storedState - Server-stored state value
   * @returns True if state is valid
   */
  validateStateParameter(state: string, storedState: string): boolean {
    if (!state || !storedState) {
      return false
    }
    
    // Constant-time comparison to prevent timing attacks
    return this.constantTimeCompare(state, storedState)
  }
  
  /**
   * Performs constant-time string comparison to prevent timing attacks
   * 
   * @param a - First string
   * @param b - Second string
   * @returns True if strings are equal
   */
  private constantTimeCompare(a: string, b: string): boolean {
    if (a.length !== b.length) {
      return false
    }
    
    let result = 0
    for (let i = 0; i < a.length; i++) {
      result |= a.charCodeAt(i) ^ b.charCodeAt(i)
    }
    
    return result === 0
  }
  
  /**
   * Extracts user ID safely from request context
   * 
   * @param req - HTTP request
   * @returns User ID or throws error
   */
  async getUserId(req: Request): Promise<string> {
    const userContext = await this.getUserContext(req)
    return userContext.userId || userContext.sessionId || ''
  }
  
  /**
   * Checks if user is authenticated (not anonymous)
   * 
   * @param req - HTTP request
   * @returns True if user is authenticated
   */
  async isAuthenticated(req: Request): Promise<boolean> {
    try {
      const userContext = await this.getUserContext(req)
      return userContext.type === 'authenticated'
    } catch {
      return false
    }
  }
  
  /**
   * Checks if user is anonymous
   * 
   * @param req - HTTP request
   * @returns True if user is anonymous
   */
  async isAnonymous(req: Request): Promise<boolean> {
    try {
      const userContext = await this.getUserContext(req)
      return userContext.type === 'anonymous'
    } catch {
      return false
    }
  }

  /**
   * Checks if the user is an admin based on their profile
   *
   * @param userId - User ID to check
   * @returns Promise resolving to true if user is admin
   */
  private async isAdminUser(userId: string): Promise<boolean> {
    const userProfile = await this.getUserProfile(userId)
    return userProfile?.is_admin === true
  }

  /**
   * Fetches the user's active subscription from the database
   *
   * Returns a valid subscription if:
   * - Status is 'active', 'trial', 'authenticated', or 'pending_cancellation'
   * - Status is 'cancelled' but still within the billing period
   *
   * @param userId - User ID to fetch subscription for
   * @returns Promise resolving to active subscription or null
   */
  private async getActiveSubscription(userId: string): Promise<Subscription | null> {
    if (!this.supabaseServiceClient) {
      console.log('[AuthService] getActiveSubscription - no service client')
      return null
    }

    console.log('[AuthService] getActiveSubscription - querying for userId:', userId)

    // Query subscription - each user has exactly ONE subscription record (enforced by unique constraint)
    // No need for .limit(1) or .order() since uniqueness is guaranteed at database level
    // NOW INCLUDES 'trial' status for users in trial period
    const { data: subscription, error } = await this.supabaseServiceClient
      .from('subscriptions')
      .select('status, plan_type, current_period_end, cancel_at_cycle_end')
      .eq('user_id', userId)
      .in('status', ['trial', 'active', 'authenticated', 'pending_cancellation', 'cancelled'])
      .maybeSingle()

    console.log('[AuthService] getActiveSubscription - query result:', {
      error: error?.message,
      subscription,
      hasData: !!subscription
    })

    if (error || !subscription) {
      console.log('[AuthService] getActiveSubscription - returning null (error or no data)')
      return null
    }

    // Validate subscription is currently active
    const isActive =
      subscription.status === 'trial' ||  // NEW: Trial subscriptions are active
      subscription.status === 'active' ||
      subscription.status === 'authenticated' ||
      subscription.status === 'pending_cancellation' ||
      // Cancelled but still within billing period
      (subscription.status === 'cancelled' &&
       subscription.cancel_at_cycle_end &&
       subscription.current_period_end &&
       new Date(subscription.current_period_end) > new Date())

    console.log('[AuthService] getActiveSubscription - isActive:', isActive)
    return isActive ? subscription : null
  }

  /**
   * Maps a subscription's plan_type to a UserPlan tier
   *
   * - 'premium*' → 'premium' (unlimited access)
   * - 'plus*' → 'plus' (50 tokens/day)
   * - 'standard*' → 'standard' (20 tokens/day)
   * - 'free*' → 'free' (8 tokens/day)
   * - fallback → 'standard' (default)
   *
   * @param subscription - Active subscription to map
   * @returns UserPlan tier based on subscription plan_type
   */
  private mapSubscriptionToPlan(subscription: Subscription): UserPlan {
    if (subscription.plan_type?.startsWith('premium')) {
      return 'premium'
    }
    if (subscription.plan_type?.startsWith('plus')) {
      return 'plus'
    }
    if (subscription.plan_type?.startsWith('standard')) {
      return 'standard'
    }
    if (subscription.plan_type?.startsWith('free')) {
      return 'free'
    }
    return 'standard'
  }

  /**
   * Determines the user's subscription plan based on context and profile
   *
   * This method implements the SIMPLIFIED user plan logic for the token system:
   * - Anonymous users → 'free' plan (8 tokens/day)
   * - Admin users (user_profiles.is_admin = true) → 'premium' plan (unlimited)
   * - Active subscription users → Plan from subscription record (premium/plus/standard/trial/free)
   * - Premium trial active → 'premium' plan (7-day trial for new users)
   * - Default fallback → 'free' plan
   *
   * NOTE: Trial users now have subscription records with status='trial' in the database.
   * This eliminates the need for complex time-based trial period checks.
   *
   * Daily token limits are defined in DEFAULT_PLAN_CONFIGS (token-types.ts):
   * - free: 8 tokens/day
   * - standard: 20 tokens/day
   * - plus: 50 tokens/day
   * - premium: unlimited
   *
   * @param req - HTTP request to get user context from
   * @returns Promise resolving to user's subscription plan
   */
  async getUserPlan(req: Request): Promise<UserPlan> {
    // Import Premium trial helper
    const { isInPremiumTrial } = await import('../config/subscription-config.ts')

    try {
      const userContext = await this.getUserContext(req)
      console.log('[AuthService] getUserPlan - userContext:', { type: userContext.type, userId: userContext.userId })

      // 1. Anonymous users always get free plan
      if (userContext.type === 'anonymous') {
        console.log('[AuthService] getUserPlan - returning free (anonymous)')
        return 'free'
      }

      // 2. Must be authenticated with valid userId
      if (userContext.type !== 'authenticated' || !userContext.userId) {
        console.log('[AuthService] getUserPlan - returning free (not authenticated)')
        return 'free'
      }

      // 3. Admin users get premium access
      const isAdmin = await this.isAdminUser(userContext.userId)
      console.log('[AuthService] getUserPlan - isAdmin:', isAdmin)
      if (isAdmin) {
        console.log('[AuthService] getUserPlan - returning premium (admin)')
        return 'premium'
      }

      // 4. Check for subscription in database (now includes trial subscriptions!)
      const subscription = await this.getActiveSubscription(userContext.userId)
      console.log('[AuthService] getUserPlan - subscription:', subscription)
      if (subscription) {
        const plan = this.mapSubscriptionToPlan(subscription)
        console.log('[AuthService] getUserPlan - mapped plan:', plan, 'from plan_type:', subscription.plan_type, 'status:', subscription.status)
        return plan
      }

      // 5. Check for active Premium trial (7-day trial for new users)
      const premiumTrialEndAt = await this.getPremiumTrialEndDate(userContext.userId)
      console.log('[AuthService] getUserPlan - premiumTrialEndAt:', premiumTrialEndAt)
      if (isInPremiumTrial(premiumTrialEndAt)) {
        console.log('[AuthService] getUserPlan - returning premium (7-day trial)')
        return 'premium'
      }

      // 6. Default fallback: Users without subscription get free plan
      // NOTE: This should rarely happen as all users should have a subscription record now
      // (either trial during global trial period, or free after trial expires)
      console.log('[AuthService] getUserPlan - returning free (no subscription found - this should be rare)')
      return 'free'

    } catch (error) {
      console.warn('[AuthService] Failed to determine user plan, defaulting to free:', error)
      // Fail safe: return free plan if determination fails
      return 'free'
    }
  }

  /**
   * Gets user's Premium trial end date from user_profiles
   *
   * @param userId - User ID to look up
   * @returns Promise resolving to Premium trial end date or null
   */
  private async getPremiumTrialEndDate(userId: string): Promise<Date | null> {
    if (!this.supabaseServiceClient) {
      return null
    }

    const { data: profile } = await this.supabaseServiceClient
      .from('user_profiles')
      .select('premium_trial_end_at')
      .eq('id', userId)
      .maybeSingle()

    if (profile?.premium_trial_end_at) {
      return new Date(profile.premium_trial_end_at)
    }

    return null
  }

  /**
   * Gets user's account creation date
   *
   * @param userId - User ID to look up
   * @returns Promise resolving to user's creation date
   */
  private async getUserCreatedAt(userId: string): Promise<Date> {
    if (!this.supabaseServiceClient) {
      return new Date() // Default to now if no service client (treat as new user)
    }

    // First try user_profiles
    const { data: profile } = await this.supabaseServiceClient
      .from('user_profiles')
      .select('created_at')
      .eq('id', userId)
      .maybeSingle()

    if (profile?.created_at) {
      return new Date(profile.created_at)
    }

    // Fallback to auth.users via RPC
    const { data: authCreatedAt } = await this.supabaseServiceClient
      .rpc('get_user_created_at', { p_user_id: userId })

    if (authCreatedAt) {
      return new Date(authCreatedAt)
    }

    // Default to now if not found (treat as new user)
    return new Date()
  }

  /**
   * Handles Supabase query errors for user profile lookups
   *
   * @param err - Error from Supabase query
   * @param context - Context string for logging
   * @returns True if error should be treated as "no rows found" (return null)
   * @throws Error if the error is not a "no rows found" error
   */
  private handleSupabaseError(err: any, context: string): boolean {
    if (err?.code === 'PGRST116') {
      // PGRST116 = no rows found - this is expected for new users
      return true
    }

    // Log actual errors with higher severity and full details
    console.error(`[AuthService] CRITICAL ERROR in ${context}:`, {
      message: err?.message,
      code: err?.code,
      details: err?.details,
      hint: err?.hint,
      fullError: err
    })

    // Re-throw the error so callers can handle it appropriately
    throw new Error(`Database error in ${context}: ${err?.message || 'Unknown error'}`)
  }

  /**
   * Gets user profile information from database
   * 
   * @param userId - User ID to get profile for
   * @returns Promise resolving to user profile or null if not found
   */
  private async getUserProfile(userId: string): Promise<UserProfile | null> {
    if (!this.supabaseServiceClient) {
      console.warn('[AuthService] No service client available for user profile lookup')
      return null
    }
    
    const { data, error } = await this.supabaseServiceClient
      .from('user_profiles')
      .select('id, is_admin, language_preference, theme_preference')
      .eq('id', userId)
      .single()
    
    if (error && this.handleSupabaseError(error, 'Failed to get user profile')) {
      return null
    }
    
    return data as UserProfile
  }


  /**
   * Determines user plan from user context and profile (static version)
   * 
   * This is a helper method that can be used when you already have
   * the user context and profile information.
   * 
   * @param userContext - User context from getUserContext()
   * @param userProfile - Optional user profile from database
   * @returns User's subscription plan
   */
  static determineUserPlan(userContext: UserContext, userProfile?: UserProfile | null): UserPlan {
    // Anonymous users always get free plan
    if (userContext.type === 'anonymous') {
      return 'free'
    }
    
    // Check if user is admin (gets premium access)
    if (userProfile?.is_admin) {
      return 'premium'
    }
    
    // TODO: Add subscription logic when implemented
    // if (userProfile?.subscription?.status === 'active') {
    //   return 'premium'
    // }
    
    // Default: authenticated users get standard plan
    return 'standard'
  }
}

