/**
 * Token Status Edge Function
 * 
 * Provides current token balance and status information for users.
 * Supports both authenticated and anonymous users with appropriate
 * plan-based information and token details.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'

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
 * Gets human-readable plan description
 * 
 * @param userPlan - User's subscription plan
 * @returns Descriptive text for the plan
 */
function getPlanDescription(userPlan: string): string {
  switch (userPlan) {
    case 'free':
      return 'Anonymous users with 20 tokens daily'
    case 'standard':
      return 'Authenticated users with 100 tokens daily + purchase option'
    case 'premium':
      return 'Unlimited access for admin and subscription users'
    default:
      return 'Unknown plan'
  }
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
createSimpleFunction(handleTokenStatus, {
  enableAnalytics: true,
  allowedMethods: ['GET']
})