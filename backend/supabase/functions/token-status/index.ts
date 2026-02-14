/**
 * Token Status Edge Function
 * 
 * Provides current token balance and status information for users.
 * Supports both authenticated and anonymous users with appropriate
 * plan-based information and token details.
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { DEFAULT_PLAN_CONFIGS, type UserPlan } from '../_shared/types/token-types.ts'

/**
 * Token status response interface
 */
interface TokenStatusResponse {
  readonly success: boolean
  readonly data: {
    readonly available_tokens: number
    readonly purchased_tokens: number
    readonly total_tokens: number
    readonly daily_limit: number
    readonly total_consumed_today: number
    readonly last_reset: string
    readonly user_plan: string
    readonly authentication_type: string
    readonly is_premium: boolean
    readonly unlimited_usage: boolean
    readonly can_purchase_tokens: boolean
    readonly plan_description: string
    readonly next_reset_time?: string
  }
}

/**
 * Token status handler
 * 
 * This handler provides comprehensive token status information:
 * 1. Gets user context securely from AuthService
 * 2. Determines user plan based on authentication and profile
 * 3. Retrieves current token balance from TokenService
 * 4. Returns formatted status with plan information
 */
async function handleTokenStatus(req: Request, services: ServiceContainer): Promise<Response> {
  const { authService, tokenService } = services
  // 1. Get user context SECURELY from AuthService
  const userContext = await authService.getUserContext(req)
  
  // 2. Determine user plan based on context
  const userPlan = await authService.getUserPlan(req)
  
  // 3. Get identifier for token operations
  const identifier = userContext.type === 'authenticated' 
    ? userContext.userId! 
    : userContext.sessionId!
    
  // 4. Get current token information
  const tokenInfo = await tokenService.getUserTokens(identifier, userPlan)
  
  // 5. Calculate next reset time for non-premium users
  let nextResetTime: string | undefined
  if (!tokenService.isUnlimitedPlan(userPlan)) {
    // Calculate next midnight UTC
    const now = new Date()
    const nextReset = new Date(now)
    nextReset.setUTCDate(nextReset.getUTCDate() + 1)
    nextReset.setUTCHours(0, 0, 0, 0)
    nextResetTime = nextReset.toISOString()
  }
  
  // 6. Build comprehensive response
  const response: TokenStatusResponse = {
    success: true,
    data: {
      available_tokens: tokenInfo.availableTokens,
      purchased_tokens: tokenInfo.purchasedTokens,
      total_tokens: tokenInfo.totalTokens,
      daily_limit: tokenInfo.dailyLimit,
      total_consumed_today: tokenInfo.totalConsumedToday,
      last_reset: tokenInfo.lastReset,
      user_plan: userPlan,
      authentication_type: userContext.type,
      is_premium: tokenService.isUnlimitedPlan(userPlan),
      unlimited_usage: tokenService.isUnlimitedPlan(userPlan),
      can_purchase_tokens: tokenService.canPurchaseTokens(userPlan),
      plan_description: getPlanDescription(userPlan),
      next_reset_time: nextResetTime
    }
  }
  
  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

/**
 * Gets human-readable plan description dynamically from config
 *
 * Uses DEFAULT_PLAN_CONFIGS as the single source of truth for plan details.
 * This ensures descriptions stay in sync with actual token limits.
 *
 * @param userPlan - User's subscription plan
 * @returns Descriptive text for the plan with accurate token limits
 */
function getPlanDescription(userPlan: string): string {
  // Validate plan exists in config
  if (!(userPlan in DEFAULT_PLAN_CONFIGS)) {
    return 'Unknown plan'
  }

  const planConfig = DEFAULT_PLAN_CONFIGS[userPlan as UserPlan]

  // Return the description directly from config (already includes token counts)
  return planConfig.description
}

/**
 * Request validation for token status
 * 
 * Token status endpoint accepts GET requests only and requires no parameters.
 * Authentication is handled by the AuthService.
 */
async function parseAndValidateRequest(req: Request): Promise<void> {
  if (req.method !== 'GET') {
    throw new AppError(
      'METHOD_NOT_ALLOWED',
      'Token status endpoint only supports GET requests',
      405
    )
  }
  
  // No additional validation needed for GET request
}

// Create the Edge Function using the factory pattern
createFunction(handleTokenStatus, {
  requireAuth: true,  // SECURITY: Force authentication for token status
  enableAnalytics: true,
  allowedMethods: ['GET']
})