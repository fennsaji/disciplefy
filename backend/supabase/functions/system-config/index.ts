/**
 * System Configuration Public Endpoint
 *
 * PUBLIC ENDPOINT - No authentication required
 *
 * This endpoint MUST be accessible without auth to allow:
 * - Displaying maintenance screen when maintenance mode is active
 * - Checking app version requirements before user logs in
 * - Loading feature flags for unauthenticated users
 */

import { getSystemConfig } from '../_shared/services/system-config-service.ts'
import { getFeatureFlags } from '../_shared/services/feature-flag-service.ts'
import { MemoryVerseConfigService } from '../_shared/services/memory-verse-config-service.ts'
import { createClient } from 'jsr:@supabase/supabase-js@2'

// CORS headers for all responses
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Content-Type': 'application/json',
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Only allow GET requests
  if (req.method !== 'GET') {
    return new Response(
      JSON.stringify({ success: false, error: 'Method not allowed' }),
      { status: 405, headers: corsHeaders }
    )
  }

  try {
    console.log('[SystemConfig] Fetching system configuration (public endpoint)')

    // Fetch system config (uses 5-min cache)
    const systemConfig = await getSystemConfig()

    // Fetch feature flags (uses 5-min cache)
    const featureFlags = await getFeatureFlags()

    // Fetch memory verse config (uses 5-min cache)
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey)
    const memoryVerseConfigService = new MemoryVerseConfigService(supabaseClient)
    const memoryVerseConfig = await memoryVerseConfigService.getMemoryVerseConfig()

    // Transform feature flags into simple object
    const flagsObject: Record<string, any> = {}
    featureFlags.forEach(flag => {
      flagsObject[flag.featureKey] = {
        enabled: flag.isEnabled,
        plans: flag.enabledForPlans,
        displayMode: flag.displayMode, // 'hide' | 'lock'
      }
    })

    console.log('[SystemConfig] Returning config:', {
      maintenanceModeEnabled: systemConfig.maintenanceModeEnabled,
      flagCount: featureFlags.length,
      memoryVerseConfigLoaded: !!memoryVerseConfig,
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
          memoryVerseConfig: {
            unlockLimits: memoryVerseConfig.unlockLimits,
            verseLimits: memoryVerseConfig.verseLimits,
            availableModes: memoryVerseConfig.availableModes,
            spacedRepetition: memoryVerseConfig.spacedRepetition,
            gamification: memoryVerseConfig.gamification,
          },
        },
      }),
      {
        headers: corsHeaders,
        status: 200,
      }
    )
  } catch (error) {
    console.error('[SystemConfig] Error:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: 'Failed to fetch system configuration',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        headers: corsHeaders,
        status: 500,
      }
    )
  }
})
