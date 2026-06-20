/**
 * Refresh Stale Memory Verses - Scheduled Background Job
 *
 * API.Bible's terms require stored content to be refreshed at least every 30 days.
 * memory_verses with source_type = 'daily_verse' hold API.Bible verse text, so this
 * job re-fetches the text for any such row whose verse_text was last synced more
 * than 30 days ago, and stamps verse_text_synced_at. manual / ai_generated rows are
 * not API.Bible content and are left untouched.
 *
 * Processes a bounded batch per run; remaining rows are picked up on the next run.
 * Schedule: daily via external scheduler / pg_cron (e.g. `0 4 * * *`).
 */

import { createServiceRoleFunction } from '../_shared/core/function-factory.ts'
import { fetchBibleVerse } from '../_shared/services/bible-api-service.ts'
import { isBibleApiCallsEnabled } from '../_shared/services/bible-availability.ts'

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000
const BATCH_LIMIT = 200

createServiceRoleFunction(async (_req, supabase) => {
  if (!(await isBibleApiCallsEnabled())) {
    console.log('[REFRESH-MEMORY-VERSES] bible_api_calls_enabled is OFF — skipping run')
    return { success: true, skipped: true, reason: 'bible_api_calls_enabled is off', refreshed_count: 0, failed_count: 0 }
  }

  const cutoff = new Date(Date.now() - THIRTY_DAYS_MS).toISOString()
  console.log('[REFRESH-MEMORY-VERSES] Refreshing daily_verse rows synced before', cutoff)

  const { data: stale, error } = await supabase
    .from('memory_verses')
    .select('id, verse_reference, language')
    .eq('source_type', 'daily_verse')
    .lt('verse_text_synced_at', cutoff)
    .order('verse_text_synced_at', { ascending: true })
    .limit(BATCH_LIMIT)

  if (error) {
    console.error('[REFRESH-MEMORY-VERSES] Query failed:', error)
    return { success: false, error: error.message, refreshed_count: 0, failed_count: 0 }
  }

  let refreshed = 0
  let failed = 0

  for (const row of stale ?? []) {
    const language = row.language as 'en' | 'hi' | 'ml'
    if (language !== 'en' && language !== 'hi' && language !== 'ml') {
      failed++
      console.warn(`[REFRESH-MEMORY-VERSES] Skipping ${row.id}: unsupported language "${row.language}"`)
      continue
    }

    try {
      const verse = await fetchBibleVerse(row.verse_reference, language)
      if (!verse.text) throw new Error('empty verse text')

      const { error: updateError } = await supabase
        .from('memory_verses')
        .update({
          verse_text: verse.text,
          verse_text_synced_at: new Date().toISOString(),
        })
        .eq('id', row.id)

      if (updateError) throw updateError
      refreshed++
    } catch (e) {
      // Leave the row untouched so it is retried on the next run.
      failed++
      console.error(
        `[REFRESH-MEMORY-VERSES] Failed for ${row.id} (${row.verse_reference}/${language}):`,
        e instanceof Error ? e.message : String(e)
      )
    }
  }

  console.log(`[REFRESH-MEMORY-VERSES] ✅ Refreshed ${refreshed}, failed ${failed}, scanned ${stale?.length ?? 0}`)

  return {
    success: true,
    refreshed_count: refreshed,
    failed_count: failed,
    scanned_count: stale?.length ?? 0,
    batch_limit: BATCH_LIMIT,
    timestamp: new Date().toISOString(),
  }
}, {
  allowedMethods: ['POST', 'GET']
})
