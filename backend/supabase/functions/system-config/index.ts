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

import { getSystemConfig, getSystemConfigRows } from '../_shared/services/system-config-service.ts'
import { getFeatureFlags, isTesterEmail, applyTesterBypass } from '../_shared/services/feature-flag-service.ts'
import { MemoryVerseConfigService } from '../_shared/services/memory-verse-config-service.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { verifyUserToken } from '../_shared/auth/jwt-verifier.ts'

/**
 * One memory verse config service per worker, so its 5-minute cache actually
 * survives between requests. It reads the same cached get_system_configs rows
 * as getSystemConfig, so the RPC runs once per TTL, not once per reader.
 */
let memoryVerseConfigService: MemoryVerseConfigService | null = null
function getMemoryVerseConfigService(): MemoryVerseConfigService {
  if (!memoryVerseConfigService) {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    )
    memoryVerseConfigService = new MemoryVerseConfigService(supabaseClient, getSystemConfigRows)
  }
  return memoryVerseConfigService
}

/**
 * The response is the same for every caller unless tester bypass applied, so
 * it may be shared briefly; Vary keeps an authorised caller from being served
 * an anonymous copy. A tester-specific response is never stored.
 */
const PUBLIC_CACHE_CONTROL = 'public, max-age=60, stale-while-revalidate=300'
const PRIVATE_CACHE_CONTROL = 'private, no-store'

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

    // System config, feature flags and memory verse config are independent
    // (all 5-min cached); read them together rather than one after another.
    const [systemConfig, featureFlags, memoryVerseConfig] = await Promise.all([
      getSystemConfig(),
      getFeatureFlags(),
      getMemoryVerseConfigService().getMemoryVerseConfig(),
    ])

    // Tester bypass: if the caller sent a valid JWT and their email is in the
    // feature_tester_emails allowlist, report allow_tester_bypass flags as enabled.
    // Endpoint stays public — no JWT means no bypass, same response as before.
    // Tester emails themselves are NEVER included in the response.
    // Only resolve the caller when at least one flag actually opts into bypass —
    // otherwise the getUser() round-trip can never change the response, and this
    // is a public endpoint every client hits on startup.
    let testerBypassActive = false
    const authHeader = req.headers.get('Authorization')
    const anyFlagAllowsBypass = featureFlags.some(f => f.allowTesterBypass)
    if (anyFlagAllowsBypass && authHeader?.startsWith('Bearer ')) {
      try {
        const user = await verifyUserToken(authHeader.replace('Bearer ', ''), Deno.env.get('SUPABASE_URL')!, async () => {
          const anonClient = createClient(
            Deno.env.get('SUPABASE_URL')!,
            Deno.env.get('SUPABASE_ANON_KEY')!,
            { global: { headers: { Authorization: authHeader } }, auth: { autoRefreshToken: false, persistSession: false } }
          )
          const { data: { user } } = await anonClient.auth.getUser()
          return user ? { id: user.id, email: user.email ?? undefined, is_anonymous: user.is_anonymous === true } : null
        })
        if (user && !user.is_anonymous && user.email) {
          testerBypassActive = await isTesterEmail(user.email)
        }
      } catch (authError) {
        // Invalid/expired token → treat as anonymous, no bypass. Never fail the endpoint.
        console.warn('[SystemConfig] JWT resolution failed, continuing without bypass:', authError)
      }
    }

    const resolvedFlags = applyTesterBypass(featureFlags, testerBypassActive)

    // Transform feature flags into simple object
    const flagsObject: Record<string, any> = {}
    resolvedFlags.forEach(flag => {
      flagsObject[flag.featureKey] = {
        enabled: flag.isEnabled,
        displayMode: flag.displayMode, // 'hide' | 'lock'
        plans: flag.enabledForPlans,  // required by frontend for plan-based access checks
      }
    })

    console.log('[SystemConfig] Returning config:', {
      maintenanceModeEnabled: systemConfig.maintenanceModeEnabled,
      flagCount: featureFlags.length,
      testerBypassActive,
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
          testerBypassActive,
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
        headers: {
          ...corsHeaders,
          'Cache-Control': testerBypassActive ? PRIVATE_CACHE_CONTROL : PUBLIC_CACHE_CONTROL,
          'Vary': 'Authorization',
        },
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
