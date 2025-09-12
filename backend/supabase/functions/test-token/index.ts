/**
 * Test Token System Edge Function
 * 
 * Simple test function to debug token system integration issues.
 */

import { createFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'

/**
 * Simple test handler to isolate token system issues
 * SECURITY: Only accessible to authenticated admin/premium users
 */
async function handleTestToken(req: Request, services: ServiceContainer): Promise<Response> {
  try {
    console.log('[TestToken] Starting test...')
    
    // SECURITY CHECK: Verify user is authenticated and authorized
    const userContext = await services.authService.getUserContext(req)
    
    if (userContext.type !== 'authenticated') {
      return new Response(JSON.stringify({
        success: false,
        error: 'Authentication required'
      }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    const userPlan = await services.authService.getUserPlan(req)
    
    // SECURITY CHECK: Only admin or premium users can access debug data
    const isAdmin = userContext.userType === 'admin'
    const isPremium = userPlan === 'premium'
    
    if (!isAdmin && !isPremium) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Unauthorized: Admin or premium access required'
      }), {
        status: 403,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log('[TestToken] Authorized user accessing debug endpoint')
    
    // Test 1: Check if services are available
    console.log('[TestToken] Services available:', {
      authService: !!services.authService,
      tokenService: !!services.tokenService
    })
    
    console.log('[TestToken] User context:', userContext)
    console.log('[TestToken] User plan:', userPlan)
    
    // Test 2: Try basic token service methods
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
        userContext: {
          type: userContext.type,
          userId: userContext.userId,
          userType: userContext.userType
        },
        userPlan,
        tokenServiceMethods: {
          canPurchase,
          isUnlimited
        },
        timestamp: new Date().toISOString()
      }
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
    
  } catch (error) {
    // Log full error details server-side for debugging
    console.error('[TestToken] Error:', error)
    console.error('[TestToken] Stack trace:', error instanceof Error ? error.stack : 'No stack trace')
    
    // Return sanitized error response to client
    return new Response(JSON.stringify({
      success: false,
      error: 'Internal server error'
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
}

// Create and export the Edge Function
export default createFunction(handleTestToken, {
  requireAuth: true,  // SECURITY: Force authentication
  enableAnalytics: false,
  allowedMethods: ['GET']
})