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

/**
 * User context representing authenticated or anonymous users
 */
export interface UserContext {
  readonly type: 'authenticated' | 'anonymous'
  readonly id: string // User ID for authenticated, Session ID for anonymous
  readonly userId?: string // Explicit user ID for authenticated users
  readonly sessionId?: string // Explicit session ID for anonymous users
}

/**
 * Authentication result with additional metadata
 */
export interface AuthResult {
  readonly userContext: UserContext
  readonly user: any // Raw user object from Supabase
  readonly session: any // Raw session object from Supabase
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
    private readonly supabaseAnonKey: string
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
      
      // Create standardized user context
      const userContext: UserContext = {
        type: user.is_anonymous ? 'anonymous' : 'authenticated',
        id: user.id,
        userId: user.is_anonymous ? undefined : user.id,
        sessionId: user.is_anonymous ? user.id : undefined
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
      id: user.id,
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
    return userContext.id
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
}

