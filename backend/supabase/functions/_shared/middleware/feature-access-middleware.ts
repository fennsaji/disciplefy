/**
 * Feature Access Middleware
 *
 * Validates that users have access to restricted features before executing operations.
 * Prevents bypass attacks by enforcing server-side feature flag checks.
 */

import { AppError } from '../utils/error-handler.ts'
import { getFeatureFlags } from '../services/feature-flag-service.ts'

/**
 * Check if user has access to a feature
 *
 * @param userId - User ID
 * @param userPlan - User's subscription plan
 * @param featureKey - Feature key to check
 * @throws AppError if user lacks access
 *
 * @example
 * ```typescript
 * await checkFeatureAccess(userId, userPlan, 'ai_discipler')
 * ```
 */
export async function checkFeatureAccess(
  userId: string,
  userPlan: string,
  featureKey: string
): Promise<void> {
  // Fetch feature flags
  const featureFlags = await getFeatureFlags()
  const feature = featureFlags.find(f => f.featureKey === featureKey)

  // Feature not found or disabled globally
  if (!feature || !feature.isEnabled) {
    console.log(`[FeatureAccess] Feature '${featureKey}' is disabled globally`)
    throw new AppError(
      'FEATURE_DISABLED',
      `This feature is currently disabled. Please try again later.`,
      403
    )
  }

  // Check if user's plan has access
  const hasAccess = feature.enabledForPlans.includes(userPlan)

  if (!hasAccess) {
    console.log(
      `[FeatureAccess] User ${userId} (${userPlan}) lacks access to '${featureKey}' (requires: ${feature.enabledForPlans.join(', ')})`
    )

    // Determine upgrade plan
    const planHierarchy = ['free', 'standard', 'plus', 'premium']
    const currentIndex = planHierarchy.indexOf(userPlan.toLowerCase())

    let upgradePlan = 'premium' // Default to premium
    for (const plan of planHierarchy) {
      if (feature.enabledForPlans.includes(plan)) {
        const planIndex = planHierarchy.indexOf(plan)
        if (planIndex > currentIndex) {
          upgradePlan = plan
          break
        }
      }
    }

    throw new AppError(
      'FEATURE_LOCKED',
      `This feature requires ${upgradePlan} plan. Upgrade to access. (Required: ${feature.enabledForPlans.join(', ')})`,
      403
    )
  }

  console.log(`[FeatureAccess] User ${userId} (${userPlan}) has access to '${featureKey}'`)
}

/**
 * Check if user has access to ANY of the provided features
 *
 * Useful when multiple features can fulfill the requirement
 *
 * @param userId - User ID
 * @param userPlan - User's subscription plan
 * @param featureKeys - Array of feature keys to check
 * @throws AppError if user lacks access to all features
 *
 * @example
 * ```typescript
 * // User needs access to at least one study mode
 * await checkAnyFeatureAccess(userId, userPlan, [
 *   'standard_study_mode',
 *   'deep_dive_mode',
 *   'lectio_divina_mode'
 * ])
 * ```
 */
export async function checkAnyFeatureAccess(
  userId: string,
  userPlan: string,
  featureKeys: string[]
): Promise<void> {
  const featureFlags = await getFeatureFlags()

  let hasAccessToAny = false
  const requiredPlans = new Set<string>()

  for (const featureKey of featureKeys) {
    const feature = featureFlags.find(f => f.featureKey === featureKey)

    if (feature && feature.isEnabled && feature.enabledForPlans.includes(userPlan)) {
      hasAccessToAny = true
      break
    }

    if (feature) {
      feature.enabledForPlans.forEach(plan => requiredPlans.add(plan))
    }
  }

  if (!hasAccessToAny) {
    console.log(
      `[FeatureAccess] User ${userId} (${userPlan}) lacks access to any of: ${featureKeys.join(', ')}`
    )

    throw new AppError(
      'FEATURE_LOCKED',
      `This operation requires a premium plan. Upgrade to access. (Required plans: ${Array.from(requiredPlans).join(', ')})`,
      403
    )
  }

  console.log(`[FeatureAccess] User ${userId} (${userPlan}) has access to at least one feature`)
}
