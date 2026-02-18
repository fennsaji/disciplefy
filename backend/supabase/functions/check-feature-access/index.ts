/**
 * Check Feature Access Edge Function
 *
 * Validates feature access server-side to prevent bypass attacks.
 * Used by frontend to verify user has permission to use a feature.
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { getFeatureFlags } from '../_shared/services/feature-flag-service.ts'

/**
 * Request body interface
 */
interface CheckFeatureAccessRequest {
  feature_key: string
}

/**
 * Response interface
 */
interface CheckFeatureAccessResponse {
  has_access: boolean
  is_locked: boolean
  display_mode: 'hide' | 'lock'
  required_plans: string[]
  current_plan: string
  upgrade_plan: string | null
}

/**
 * Main handler for feature access check
 */
async function handleCheckFeatureAccess(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  try {
    // 1. Parse request body
    const body: CheckFeatureAccessRequest = await req.json()
    const { feature_key } = body

    if (!feature_key) {
      throw new AppError(
        'INVALID_REQUEST',
        'feature_key is required',
        400
      )
    }

    // 2. Authenticate user
    const userContext = await services.authService.getUserContext(req)

    if (userContext.type !== 'authenticated') {
      throw new AppError(
        'AUTHENTICATION_REQUIRED',
        'You must be logged in to check feature access',
        401
      )
    }

    const userId = userContext.userId!

    // 3. Rate limiting
    await services.rateLimiter.enforceRateLimit(userId, 'authenticated')

    // 4. Get user's current plan
    const userPlan = await services.authService.getUserPlan(req)

    // 5. Fetch feature flags
    const featureFlags = await getFeatureFlags()
    const feature = featureFlags.find(f => f.featureKey === feature_key)

    if (!feature) {
      // Feature not found or disabled
      return new Response(
        JSON.stringify({
          has_access: false,
          is_locked: false,
          display_mode: 'hide',
          required_plans: [],
          current_plan: userPlan,
          upgrade_plan: null,
        } as CheckFeatureAccessResponse),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // 6. Check access
    const hasAccess = feature.isEnabled && feature.enabledForPlans.includes(userPlan)
    const isLocked = feature.isEnabled &&
                     !feature.enabledForPlans.includes(userPlan) &&
                     feature.displayMode === 'lock'

    // 7. Determine upgrade plan
    const planHierarchy = ['free', 'standard', 'plus', 'premium']
    const currentIndex = planHierarchy.indexOf(userPlan.toLowerCase())

    let upgradePlan: string | null = null
    for (const plan of planHierarchy) {
      if (feature.enabledForPlans.includes(plan)) {
        const planIndex = planHierarchy.indexOf(plan)
        if (planIndex > currentIndex) {
          upgradePlan = plan
          break
        }
      }
    }

    // 8. Build response
    const response: CheckFeatureAccessResponse = {
      has_access: hasAccess,
      is_locked: isLocked,
      display_mode: feature.displayMode,
      required_plans: feature.enabledForPlans,
      current_plan: userPlan,
      upgrade_plan: upgradePlan,
    }

    console.log(`[CheckFeatureAccess] User ${userId} (${userPlan}) checking ${feature_key}: access=${hasAccess}`)

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('[CheckFeatureAccess] Error:', error)
    throw error
  }
}

/**
 * Export Edge Function using function factory
 */
createSimpleFunction(handleCheckFeatureAccess, {
  enableAnalytics: true,
  allowedMethods: ['POST'],
})
