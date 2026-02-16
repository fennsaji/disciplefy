/**
 * Maintenance Mode Middleware
 *
 * Blocks all requests during maintenance mode except for:
 * - Admin users (bypassed via user_profiles.is_admin check)
 * - Health check endpoints
 * - System status endpoints
 *
 * Usage (from Edge Functions):
 * ```typescript
 * import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'
 *
 * async function handler(req, services) {
 *   await checkMaintenanceMode(req, services)
 *   // ... rest of function logic
 * }
 * ```
 *
 * Usage (from within _shared directory):
 * ```typescript
 * import { checkMaintenanceMode } from './middleware/maintenance-middleware.ts'
 * // or from parent _shared:
 * import { checkMaintenanceMode } from '../middleware/maintenance-middleware.ts'
 * ```
 *
 * When maintenance mode is active, throws 'MAINTENANCE_MODE' error
 * which should be caught by the function factory error handler.
 */

import { ServiceContainer } from '../core/services.ts'
import { isMaintenanceModeEnabled } from '../services/system-config-service.ts'

// ============================================================================
// Configuration
// ============================================================================

/**
 * Endpoints that are always accessible, even during maintenance mode
 */
const ALLOWED_PATHS = [
  '/health',
  '/system-config',
  '/system-status',
  '/ping',
]

// ============================================================================
// Middleware Function
// ============================================================================

/**
 * Check if maintenance mode is enabled and block non-admin requests
 *
 * This middleware should be called at the beginning of any Edge Function
 * that should respect maintenance mode.
 *
 * @param req - HTTP request object
 * @param services - Service container with Supabase client
 * @throws Error with message 'MAINTENANCE_MODE' if maintenance mode is active and user is not admin
 *
 * @example
 * ```typescript
 * async function handleStudyGenerate(req, services) {
 *   await checkMaintenanceMode(req, services) // Throws if maintenance active
 *   // ... rest of function
 * }
 * ```
 */
export async function checkMaintenanceMode(
  req: Request,
  services: ServiceContainer
): Promise<void> {
  const url = new URL(req.url)
  const path = url.pathname

  // Allow health check and system status endpoints
  if (ALLOWED_PATHS.some(p => path.includes(p))) {
    console.log(`[Maintenance] Allowing health check endpoint: ${path}`)
    return
  }

  // Check if maintenance mode is enabled
  const maintenanceModeEnabled = await isMaintenanceModeEnabled()

  if (!maintenanceModeEnabled) {
    // Not in maintenance mode, proceed normally
    return
  }

  console.log('[Maintenance] Maintenance mode is ACTIVE')

  // Check if user is admin (admins bypass maintenance mode)
  const authHeader = req.headers.get('Authorization')

  if (authHeader) {
    try {
      // Extract JWT token
      const token = authHeader.replace('Bearer ', '')

      // Validate user with service role client
      const { data: { user }, error } = await services.supabaseServiceClient.auth.getUser(token)

      if (!error && user) {
        // User authenticated, check admin status
        const { data: profile } = await services.supabaseServiceClient
          .from('user_profiles')
          .select('is_admin')
          .eq('user_id', user.id)
          .maybeSingle()

        if (profile?.is_admin === true) {
          console.log(`[Maintenance] Admin user bypassing maintenance mode: ${user.email}`)
          return // Admin user, allow access
        } else {
          console.log(`[Maintenance] Non-admin user blocked: ${user.email}`)
        }
      }
    } catch (e) {
      console.error('[Maintenance] Error checking admin status:', e)
      // Continue to block on error (fail-safe)
    }
  }

  // Maintenance mode active and user is not admin (or no auth header)
  console.log('[Maintenance] Blocking request - maintenance mode active, user not admin')
  throw new Error('MAINTENANCE_MODE')
}

/**
 * Check if a request path is always allowed (health checks, etc.)
 *
 * @param path - URL pathname
 * @returns true if path should bypass maintenance checks
 *
 * @internal Used for testing
 */
export function isPathAllowed(path: string): boolean {
  return ALLOWED_PATHS.some(p => path.includes(p))
}
