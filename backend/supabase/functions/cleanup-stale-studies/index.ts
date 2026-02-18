/**
 * Cleanup Stale Study Guides - Scheduled Background Job
 *
 * This function runs periodically (via cron job) to clean up abandoned
 * in-progress study guide records that are blocking duplicate detection.
 *
 * Schedule: Every 5 minutes via pg_cron or external scheduler
 */

import { createServiceRoleFunction } from '../_shared/core/function-factory.ts'

createServiceRoleFunction(async (req, supabase) => {
  console.log('[CLEANUP] Starting stale study cleanup job...')

  try {
    // Call the database cleanup function
    const { data, error } = await supabase
      .rpc('cleanup_stale_in_progress_studies')
      .single()

    if (error) {
      console.error('[CLEANUP] Database cleanup failed:', error)
      return {
        success: false,
        error: error.message,
        cleaned_count: 0
      }
    }

    const { cleaned_count, cleaned_ids } = data

    if (cleaned_count > 0) {
      console.log(`[CLEANUP] ✅ Cleaned up ${cleaned_count} stale records:`, cleaned_ids)
    } else {
      console.log('[CLEANUP] No stale records found')
    }

    return {
      success: true,
      cleaned_count,
      cleaned_ids,
      timestamp: new Date().toISOString()
    }
  } catch (error) {
    console.error('[CLEANUP] Unexpected error:', error)
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
      cleaned_count: 0
    }
  }
}, {
  allowedMethods: ['POST', 'GET']
})
