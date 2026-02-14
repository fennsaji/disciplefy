/**
 * System Configuration Public Endpoint
 *
 * Public API endpoint for Flutter app to fetch:
 * - Maintenance mode status
 * - App version requirements
 * - Feature flags
 *
 * This endpoint is NOT protected by maintenance mode checks
 * (it needs to be accessible to show maintenance screen).
 *
 * Endpoint: /functions/v1/system-config
 * Method: GET
 * Auth: Not required (public endpoint)
 *
 * Response:
 * ```json
 * {
 *   "success": true,
 *   "data": {
 *     "maintenanceMode": {
 *       "enabled": false,
 *       "message": "..."
 *     },
 *     "versionControl": {
 *       "minVersion": {
 *         "android": "1.0.0",
 *         "ios": "1.0.0",
 *         "web": "1.0.0"
 *       },
 *       "latestVersion": "1.0.0",
 *       "forceUpdate": false
 *     },
 *     "featureFlags": {
 *       "voice_buddy": {
 *         "enabled": true,
 *         "plans": ["premium", "plus"]
 *       },
 *       ...
 *     }
 *   }
 * }
 * ```
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { getSystemConfig } from '../_shared/services/system-config-service.ts'
import { getFeatureFlags } from '../_shared/services/feature-flag-service.ts'

createSimpleFunction(
  async (req, services) => {
    try {
      console.log('[SystemConfig Endpoint] Fetching system configuration')

      // Fetch system config (uses 5-min cache)
      const systemConfig = await getSystemConfig()

      // Fetch feature flags (uses 5-min cache)
      const featureFlags = await getFeatureFlags()

      // Transform feature flags into simple object
      const flagsObject: Record<string, any> = {}
      featureFlags.forEach(flag => {
        flagsObject[flag.featureKey] = {
          enabled: flag.isEnabled,
          plans: flag.enabledForPlans,
        }
      })

      console.log('[SystemConfig Endpoint] Returning config:', {
        maintenanceModeEnabled: systemConfig.maintenanceModeEnabled,
        flagCount: featureFlags.length,
      })

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            maintenanceMode: {
              enabled: systemConfig.maintenanceModeEnabled,
              message: systemConfig.maintenanceModeMessage,
            },
            versionControl: {
              minVersion: systemConfig.minAppVersion,
              latestVersion: systemConfig.latestAppVersion,
              forceUpdate: systemConfig.forceUpdateEnabled,
            },
            featureFlags: flagsObject,
          },
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    } catch (error) {
      console.error('[SystemConfig Endpoint] Error:', error)

      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to fetch system configuration',
          message: error instanceof Error ? error.message : 'Unknown error',
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 500,
        }
      )
    }
  },
  {
    allowedMethods: ['GET'],
    enableAnalytics: false, // Don't log every config fetch
  }
)
