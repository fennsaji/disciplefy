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
    
    return createClient(this.supabaseUrl, this.supabaseAnonKey, {
      global: {
        headers: {
          Authorization: req.headers.get('Authorization') ?? ''
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
   * Determines the user's subscription plan based on context and profile
   * 
   * This method implements the user plan logic for the token system:
   * - Anonymous users → 'free' plan (20 tokens daily)
   * - Authenticated users → 'standard' plan (100 tokens daily) 
   * - Admin users (user_profiles.is_admin = true) → 'premium' plan (unlimited)
   * - Future: Subscription users → 'premium' plan (unlimited)
   * 
   * @param req - HTTP request to get user context from
   * @returns Promise resolving to user's subscription plan
   */
  async getUserPlan(req: Request): Promise<UserPlan> {
    try {
      const userContext = await this.getUserContext(req)
      
      // Anonymous users always get free plan
      if (userContext.type === 'anonymous') {
        return 'free'
      }
      
      // For authenticated users, check if they are admin
      if (userContext.type === 'authenticated' && userContext.userId) {
        const userProfile = await this.getUserProfile(userContext.userId)
        
        // Admin users get premium access (temporary until subscriptions)
        if (userProfile?.is_admin) {
          return 'premium'
        }
        
        // TODO: Add subscription check when subscription system is implemented
        // if (userProfile.subscription && userProfile.subscription.status === 'active') {
        //   return 'premium'
        // }
      }
      
      // Default: authenticated users without admin or subscription get standard plan
      return 'standard'
      
    } catch (error) {
      console.warn('[AuthService] Failed to determine user plan, defaulting to free:', error)
      // Fail safe: return free plan if determination fails
      return 'free'
    }
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
    
    try {
      const { data, error } = await this.supabaseServiceClient
        .from('user_profiles')
        .select('id, is_admin, language_preference, theme_preference')
        .eq('id', userId)
        .single()
      
      if (error) {
        if (error.code === 'PGRST116') {
          // No user profile found - this is okay, user might be newly created
          return null
        }
        console.error('[AuthService] Failed to get user profile:', error)
        return null
      }
      
      return data as UserProfile
      
    } catch (error) {
      console.error('[AuthService] Unexpected error getting user profile:', error)
      return null
    }
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

