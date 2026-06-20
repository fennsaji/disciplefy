/**
 * Cleanup Expired Verse Cache - Scheduled Background Job
 *
 * Deletes daily_verses_cache rows whose 30-day TTL has elapsed. The read paths
 * already skip expired rows (so stale content is never served), but expired rows
 * otherwise linger in the table. API.Bible's content-recency terms require cached
 * content to be refreshed or removed at least every 30 days — this enforces removal.
 *
 * Schedule: daily via external scheduler / pg_cron (e.g. `0 3 * * *`).
 */

import { createServiceRoleFunction } from '../_shared/core/function-factory.ts'

createServiceRoleFunction(async (_req, supabase) => {
  const now = new Date().toISOString()
  console.log('[CLEANUP-VERSE-CACHE] Deleting daily_verses_cache rows expired before', now)

  const { data, error } = await supabase
    .from('daily_verses_cache')
    .delete()
    .lt('expires_at', now)
    .select('id')

  if (error) {
    console.error('[CLEANUP-VERSE-CACHE] Delete failed:', error)
    return { success: false, error: error.message, deleted_count: 0 }
  }

  const deleted_count = data?.length ?? 0
  console.log(`[CLEANUP-VERSE-CACHE] ✅ Deleted ${deleted_count} expired rows`)

  return { success: true, deleted_count, timestamp: now }
}, {
  allowedMethods: ['POST', 'GET']
})
