/**
 * Test Token System Edge Function
 * 
 * Simple test function to debug token system integration issues.
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Simple test handler to isolate token system issues
 */
async function handleTestToken(req: Request, services: ServiceContainer): Promise<Response> {
  try {
    console.log('[TestToken] Starting test...')
    
    // Test 1: Check if services are available
    console.log('[TestToken] Services available:', {
      authService: !!services.authService,
      tokenService: !!services.tokenService
    })
    
    // Test 2: Try to get user context
    console.log('[TestToken] Getting user context...')
    const userContext = await services.authService.getUserContext(req)
    console.log('[TestToken] User context:', userContext)
    
    // Test 3: Try to get user plan
    console.log('[TestToken] Getting user plan...')
    const userPlan = await services.authService.getUserPlan(req)
    console.log('[TestToken] User plan:', userPlan)
    
    // Test 4: Try basic token service methods
    console.log('[TestToken] Testing token service methods...')
    const canPurchase = services.tokenService.canPurchaseTokens(userPlan)
    const isUnlimited = services.tokenService.isUnlimitedPlan(userPlan)
    
    console.log('[TestToken] Token service results:', {
      canPurchase,
      isUnlimited
    })
    
    return new Response(JSON.stringify({
      success: true,
      data: {
        userContext,
        userPlan,
        tokenServiceMethods: {
          canPurchase,
          isUnlimited
        }
      }
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    console.error('[TestToken] Error:', error)
    
    return new Response(JSON.stringify({
      success: false,
      error: {
        message: error instanceof Error ? error.message : 'Unknown error',
        stack: error instanceof Error ? error.stack : undefined
      }
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
}

// Create and export the Edge Function
export default createFunction(handleTestToken, {
  requireAuth: false,
  enableAnalytics: false,
  allowedMethods: ['GET']
})