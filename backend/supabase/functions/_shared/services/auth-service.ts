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
import type { VerifiedIdentity } from '../auth/jwt-verifier.ts'
import { toUserContext } from '../auth/user-context.ts'

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

  /** Identity verified by the function factory, keyed by the request it came from. */
  private readonly verifiedIdentities = new WeakMap<Request, VerifiedIdentity>()
  /** Per-request memo of getUserContext (one profile read per request). */
  private readonly contextMemo = new WeakMap<Request, Promise<UserContext>>()
  /** Per-request memo of getUserPlan (one plan RPC per request). */
  private readonly planMemo = new WeakMap<Request, Promise<UserPlan>>()

  /**
   * Records the identity the function factory already verified for this request,
   * so later calls with the same request skip the Auth server round trip.
   * Only the factory calls this, after verifying the token.
   */
  primeVerifiedIdentity(req: Request, identity: VerifiedIdentity): void {
    this.verifiedIdentities.set(req, identity)
  }

  /**
   * Returns the factory-verified identity for this request when it was derived
   * from the same token the request carries now.
   */
  private getPrimedIdentity(req: Request, token?: string): VerifiedIdentity | undefined {
    const identity = this.verifiedIdentities.get(req)
    if (!identity) return undefined
    const current = token ?? this.extractToken(req)
    return current === identity.token ? identity : undefined
  }

  /** Access token from the Authorization header, or the EventSource query fallback. */
  private extractToken(req: Request): string {
    let authToken = req.headers.get('Authorization') || ''
    if (!authToken) {
      const queryAuthToken = new URL(req.url).searchParams.get('authorization')
      if (queryAuthToken) authToken = `Bearer ${queryAuthToken}`
    }
    return authToken.replace('Bearer ', '')
  }

  /**
   * Drop-in replacement for `serviceClient.auth.getUser(token)` in handlers that
   * only need the user's id / email / anonymity. Reuses the factory verification
   * for this request; otherwise asks the Auth server as before.
   */
  async getUserFromToken(
    req: Request,
    token: string
  ): Promise<{ data: { user: { id: string; email?: string; is_anonymous: boolean } | null }; error: Error | null }> {
    const identity = this.getPrimedIdentity(req, token)
    if (identity) {
      return {
        data: { user: { id: identity.id, email: identity.email, is_anonymous: identity.isAnonymous } },
        error: null
      }
    }
    if (!this.supabaseServiceClient) {
      return { data: { user: null }, error: new Error('No service client available') }
    }
    const { data, error } = await this.supabaseServiceClient.auth.getUser(token)
    const user = data?.user
    return {
      data: {
        user: user
          ? { id: user.id, email: user.email ?? undefined, is_anonymous: user.is_anonymous === true }
          : null
      },
      error: error ?? null
    }
  }
  
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
  getUserContext(req: Request): Promise<UserContext> {
    const cached = this.contextMemo.get(req)
    if (cached) return cached
    const pending = this.resolveUserContext(req)
    this.contextMemo.set(req, pending)
    // A failed lookup is not memoised, so a retry behaves as before.
    pending.catch(() => this.contextMemo.delete(req))
    return pending
  }

  /** Identity part of a UserContext, shared with the function factory (see auth/user-context.ts). */
  private identityContext(user: { id: string; email?: string | null; is_anonymous?: boolean }): UserContext {
    return toUserContext({
      id: user.id,
      email: user.email ?? undefined,
      isAnonymous: user.is_anonymous === true
    })
  }

  private async resolveUserContext(req: Request): Promise<UserContext> {
    // Server-to-server: bypass auth.getUser() for trusted internal callers
    const internalKey = req.headers.get('X-Internal-Api-Key')
    const expectedKey = Deno.env.get('INTERNAL_API_KEY')
    if (internalKey && expectedKey && this.constantTimeCompare(internalKey, expectedKey)) {
      return {
        type: 'authenticated',
        userId: '00000000-0000-0000-0000-000000000000',
        userType: 'admin',
      }
    }

    try {
      const primed = this.getPrimedIdentity(req)
      const { data: { user }, error } = primed
        ? { data: { user: { id: primed.id, email: primed.email, is_anonymous: primed.isAnonymous } }, error: null }
        : await this.createAuthClient(req).auth.getUser()
      
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
      
      // For full accounts, check if they are admin (guests skip the profile lookup)
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
      
      // Create standardized user context. An anonymous Supabase user is an
      // authenticated guest (isGuest: true) with its own userId.
      const userContext: UserContext = {
        ...this.identityContext(user),
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
    
    const userContext: UserContext = this.identityContext(user)
    
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
      return userContext.type === 'anonymous' || userContext.isGuest === true
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
   * Returns the most recently created subscription with an active status:
   * 'trial', 'active', 'in_progress', 'created', or 'pending_cancellation'
   *
   * Note: 'cancelled' is intentionally excluded — after a plan upgrade the old
   * subscription is cancelled and a new one is created. Including 'cancelled'
   * would return the stale record instead of the new active one.
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

    // Order by created_at DESC so the newest subscription wins during upgrade transitions
    // (brief window where old cancelled + new active both exist)
    const { data: subscription, error } = await this.supabaseServiceClient
      .from('subscriptions')
      .select('status, plan_type, current_period_end, cancel_at_cycle_end')
      .eq('user_id', userId)
      .in('status', ['trial', 'active', 'in_progress', 'created', 'pending_cancellation'])
      .order('created_at', { ascending: false })
      .limit(1)
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

    console.log('[AuthService] getActiveSubscription - isActive: true (status:', subscription.status, ')')
    return subscription
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
   * Resolves the user's subscription plan tier.
   *
   * Delegates entirely to the canonical SQL function `get_user_plan_with_subscription`
   * which is the single source of truth for plan resolution across all edge functions
   * and database RPC calls.
   *
   * Resolution order (enforced in SQL):
   *   1. Anonymous / unauthenticated → 'free'
   *   2. Admin flag → 'premium'
   *   3. Active premium trial → 'premium'
   *   4. Active premium subscription → 'premium'
   *   5. Active plus subscription → 'plus'
   *   6. Active standard subscription → 'standard'
   *   7. Explicit free subscription (admin override) → 'free'
   *   8. Global standard trial period active → 'standard'
   *   9. Grace period after trial → 'standard'
   *  10. Fallback → 'free'
   *
   * @param req - HTTP request to get user context from
   * @returns Promise resolving to user's subscription plan
   */
  getUserPlan(req: Request, userContext?: UserContext): Promise<UserPlan> {
    const cached = this.planMemo.get(req)
    if (cached) return cached
    const pending = this.resolveUserPlan(req, userContext)
    this.planMemo.set(req, pending)
    return pending
  }

  /**
   * Identity needed for the plan lookup. Keeps the internal-caller check first;
   * then uses a caller-supplied or factory-verified context (no profile read),
   * falling back to the full getUserContext.
   */
  private async planIdentity(req: Request, provided?: UserContext): Promise<UserContext> {
    const internalKey = req.headers.get('X-Internal-Api-Key')
    const expectedKey = Deno.env.get('INTERNAL_API_KEY')
    if (internalKey && expectedKey && this.constantTimeCompare(internalKey, expectedKey)) {
      return this.getUserContext(req)
    }
    if (provided) return provided
    const primed = this.getPrimedIdentity(req)
    if (primed) {
      return toUserContext(primed)
    }
    return this.getUserContext(req)
  }

  private async resolveUserPlan(req: Request, provided?: UserContext): Promise<UserPlan> {
    try {
      const userContext = await this.planIdentity(req, provided)

      if (userContext.type === 'anonymous') {
        return 'free'
      }

      // Guests (Supabase anonymous users) cannot hold a subscription.
      if (userContext.isGuest) {
        return 'free'
      }

      if (userContext.type !== 'authenticated' || !userContext.userId) {
        return 'free'
      }

      // Internal system caller — always premium, no DB lookup needed
      if (userContext.userId === '00000000-0000-0000-0000-000000000000') {
        return 'premium'
      }

      if (!this.supabaseServiceClient) {
        console.warn('[AuthService] getUserPlan - no service client, defaulting to free')
        return 'free'
      }

      // Single source of truth: canonical SQL function handles all logic
      const { data: plan, error } = await this.supabaseServiceClient
        .rpc('get_user_plan_with_subscription', { p_user_id: userContext.userId })

      if (error || !plan) {
        console.warn('[AuthService] getUserPlan - RPC failed, defaulting to free:', error?.message)
        return 'free'
      }

      console.log(`[AuthService] getUserPlan - user ${userContext.userId} → ${plan}`)
      return plan as UserPlan

    } catch (error) {
      console.warn('[AuthService] getUserPlan - exception, defaulting to free:', error)
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
  /**
   * @deprecated Use the async `getUserPlan(req)` instead.
   * This static method cannot call the RPC and has no subscription awareness.
   * It only handles anonymous → free and admin → premium; all other users get 'free'.
   */
  static determineUserPlan(userContext: UserContext, userProfile?: UserProfile | null): UserPlan {
    if (userContext.type === 'anonymous' || userContext.isGuest) {
      return 'free'
    }
    if (userProfile?.is_admin) {
      return 'premium'
    }
    // Cannot resolve subscription synchronously — callers must migrate to getUserPlan(req)
    return 'free'
  }
}

