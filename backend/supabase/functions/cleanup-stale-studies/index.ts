/**
 * Cleanup Stale Study Guides - Scheduled Background Job
 *
 * This function runs periodically (via cron job) to clean up abandoned
 * in-progress study guide records that are blocking duplicate detection.
 *
 * Schedule: Every 5 minutes via pg_cron or external scheduler
 */

import { createServiceRoleFunction } from '../_shared/core/function-factory.ts'
import { TokenService } from '../_shared/services/token-service.ts'

createServiceRoleFunction(async (req, supabase) => {
  console.log('[CLEANUP] Starting stale study cleanup job...')

  try {
    // Each row is one stale record the DB just flipped generating -> failed;
    // refund_identifier is set only when that record still owes tokens back.
    const { data, error } = await supabase.rpc('cleanup_stale_in_progress_studies')

    if (error) {
      console.error('[CLEANUP] Database cleanup failed:', error)
      return {
        success: false,
        error: error.message,
        cleaned_count: 0
      }
    }

    const rows: Array<{
      cleaned_id: string
      refund_identifier: string | null
      refund_daily_tokens: number
      refund_purchased_tokens: number
    }> = data ?? []

    if (rows.length === 0) {
      console.log('[CLEANUP] No stale records found')
      return { success: true, cleaned_count: 0, cleaned_ids: [], timestamp: new Date().toISOString() }
    }

    const tokenService = new TokenService(supabase)
    let refunded = 0
    for (const row of rows) {
      if (!row.refund_identifier) continue
      const result = await tokenService.refundTokens(row.refund_identifier, row.refund_daily_tokens, row.refund_purchased_tokens)
      if (result.success) {
        refunded++
      } else {
        console.error(`[CLEANUP] Failed to refund abandoned generation ${row.cleaned_id}:`, result.errorMessage)
      }
    }

    const cleanedIds = rows.map((r) => r.cleaned_id)
    console.log(`[CLEANUP] ✅ Cleaned up ${rows.length} stale records (${refunded} refunded):`, cleanedIds)

    return {
      success: true,
      cleaned_count: rows.length,
      cleaned_ids: cleanedIds,
      refunded_count: refunded,
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
