/**
 * Reset Monthly Voice Limits Edge Function
 *
 * Cron job that runs on the 1st of every month at 00:00 UTC to reset monthly
 * voice conversation counters. This ensures users get their fresh conversation
 * allocation each month based on their subscription tier.
 *
 * Schedule: "0 0 1 * *" (monthly at midnight UTC)
 * Security: Requires CRON_SECRET authorization header
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // Verify this is an authorized cron job request
    const authHeader = req.headers.get('Authorization')
    const cronSecret = Deno.env.get('CRON_SECRET')

    if (!authHeader || !cronSecret || authHeader !== `Bearer ${cronSecret}`) {
      console.error('[ResetMonthlyVoiceLimits] Unauthorized request attempt')
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Unauthorized - Invalid or missing CRON_SECRET'
        }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client with service role key for admin operations
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    const currentMonth = new Date().toISOString().substring(0, 7) // YYYY-MM format
    const previousMonth = new Date(new Date().setMonth(new Date().getMonth() - 1))
      .toISOString()
      .substring(0, 7)
    const threeMonthsAgo = new Date(new Date().setMonth(new Date().getMonth() - 3))
      .toISOString()
      .substring(0, 7)

    console.log(`[ResetMonthlyVoiceLimits] Starting reset for month: ${currentMonth}`)
    console.log(`[ResetMonthlyVoiceLimits] Previous month: ${previousMonth}`)
    console.log(`[ResetMonthlyVoiceLimits] Will delete records older than: ${threeMonthsAgo}`)

    // Archive previous month's data for analytics (optional - for future reporting)
    const { data: archived, error: archiveError } = await supabaseClient
      .from('voice_usage_tracking')
      .select('user_id, monthly_conversations_started, monthly_conversations_completed, tier_at_time')
      .eq('month_year', previousMonth)

    if (archiveError) {
      console.error('[ResetMonthlyVoiceLimits] Error archiving previous month data:', archiveError)
    } else {
      console.log(`[ResetMonthlyVoiceLimits] Archived ${archived?.length || 0} records from ${previousMonth}`)

      // Log summary statistics
      const stats = {
        totalUsers: archived?.length || 0,
        totalConversationsStarted: archived?.reduce((sum, record) => sum + (record.monthly_conversations_started || 0), 0) || 0,
        totalConversationsCompleted: archived?.reduce((sum, record) => sum + (record.monthly_conversations_completed || 0), 0) || 0,
        byTier: archived?.reduce((acc, record) => {
          const tier = record.tier_at_time || 'unknown'
          if (!acc[tier]) {
            acc[tier] = { users: 0, conversations: 0 }
          }
          acc[tier].users++
          acc[tier].conversations += record.monthly_conversations_started || 0
          return acc
        }, {} as Record<string, { users: number; conversations: number }>)
      }

      console.log('[ResetMonthlyVoiceLimits] Previous month statistics:', JSON.stringify(stats, null, 2))
    }

    // Delete old monthly records (keep last 3 months for historical analysis)
    const { error: deleteError, count: deletedCount } = await supabaseClient
      .from('voice_usage_tracking')
      .delete({ count: 'exact' })
      .lt('month_year', threeMonthsAgo)

    if (deleteError) {
      console.error('[ResetMonthlyVoiceLimits] Error deleting old records:', deleteError)
    } else {
      console.log(`[ResetMonthlyVoiceLimits] Deleted ${deletedCount || 0} records older than ${threeMonthsAgo}`)
    }

    // Note: We don't need to explicitly reset counters to 0.
    // New monthly records with 0 counters are created automatically when
    // users start conversations (via check_and_increment_voice_quota on first
    // message, or check_voice_quota on quota display).

    console.log(`[ResetMonthlyVoiceLimits] Reset completed successfully for ${currentMonth}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Monthly voice conversation limits reset successfully',
        current_month: currentMonth,
        archived_records: archived?.length || 0,
        deleted_records: deletedCount || 0,
        statistics: archived ? {
          total_users: archived.length,
          total_conversations: archived.reduce((sum, r) => sum + (r.monthly_conversations_started || 0), 0)
        } : null
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  } catch (error) {
    console.error('[ResetMonthlyVoiceLimits] Unexpected error:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'An unexpected error occurred',
        timestamp: new Date().toISOString()
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})
