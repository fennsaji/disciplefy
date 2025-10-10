// ============================================================================
// Cleanup FCM Tokens Edge Function
// ============================================================================
// Removes expired FCM tokens from the database (90+ days inactive)
// Scheduled via GitHub Actions to run daily at 02:00 UTC

import { createSimpleFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { AppError } from '../_shared/utils/error-handler.ts';

// ============================================================================
// Configuration
// ============================================================================

const CLEANUP_CONFIG = {
  DAYS_INACTIVE: 90, // Remove tokens inactive for 90+ days
  BATCH_SIZE: 100,   // Process tokens in batches
} as const;

// ============================================================================
// Main Handler
// ============================================================================

async function handleTokenCleanup(
  req: Request,
  services: ServiceContainer
): Promise<Response> {
  // Verify cron authentication using dedicated secret
  const cronHeader = req.headers.get('X-Cron-Secret');
  const cronSecret = Deno.env.get('CRON_SECRET');

  if (!cronHeader || cronHeader !== cronSecret) {
    throw new AppError('UNAUTHORIZED', 'Cron secret authentication required', 401);
  }

  // Parse request body for optional dry_run parameter
  let dryRun = false;
  try {
    const body = await req.json();
    dryRun = body?.dry_run === true;
  } catch {
    // If body parsing fails, default to non-dry-run mode
    dryRun = false;
  }

  console.log(`Starting FCM token cleanup process... (dry_run: ${dryRun})`);

  const supabase = services.supabaseServiceClient;

  // Calculate cutoff date (90 days ago)
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - CLEANUP_CONFIG.DAYS_INACTIVE);
  const cutoffDateStr = cutoffDate.toISOString();

  console.log(`Removing tokens last updated before: ${cutoffDateStr}`);

  // Count tokens to be removed (from user_notification_tokens table)
  const { count: totalCount, error: countError } = await supabase
    .from('user_notification_tokens')
    .select('*', { count: 'exact', head: true })
    .lt('token_updated_at', cutoffDateStr);

  if (countError) {
    throw new AppError('DATABASE_ERROR', `Failed to count expired tokens: ${countError.message}`, 500);
  }

  console.log(`Found ${totalCount || 0} expired tokens to remove`);

  if (!totalCount || totalCount === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        message: 'No expired tokens to clean up',
        removedCount: 0,
        cutoffDate: cutoffDateStr,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Delete expired tokens in batches
  let totalRemoved = 0;
  let hasMore = true;

  while (hasMore) {
    // Fetch a batch of expired tokens (from user_notification_tokens table)
    const { data: expiredTokens, error: fetchError } = await supabase
      .from('user_notification_tokens')
      .select('id, user_id, fcm_token')
      .lt('token_updated_at', cutoffDateStr)
      .limit(CLEANUP_CONFIG.BATCH_SIZE);

    if (fetchError) {
      console.error(`Error fetching batch: ${fetchError.message}`);
      break;
    }

    if (!expiredTokens || expiredTokens.length === 0) {
      hasMore = false;
      break;
    }

    // Delete this batch (or count in dry-run mode)
    if (dryRun) {
      // Dry run: just count, don't delete
      totalRemoved += expiredTokens.length;
      console.log(`[DRY RUN] Would delete batch of ${expiredTokens.length} tokens (total: ${totalRemoved}/${totalCount})`);
    } else {
      // Actual deletion - delete by token IDs
      const tokenIds = expiredTokens.map(t => t.id);
      const { error: deleteError } = await supabase
        .from('user_notification_tokens')
        .delete()
        .in('id', tokenIds);

      if (deleteError) {
        console.error(`Error deleting batch: ${deleteError.message}`);
        // Stop processing to prevent infinite loop on persistent errors
        throw new AppError(
          'DATABASE_ERROR',
          `Failed to delete token batch: ${deleteError.message}`,
          500
        );
      }

      totalRemoved += expiredTokens.length;
      console.log(`Deleted batch of ${expiredTokens.length} tokens (total: ${totalRemoved}/${totalCount})`);
    }

    // Check if there are more tokens to process
    hasMore = expiredTokens.length === CLEANUP_CONFIG.BATCH_SIZE;
  }

  const completionMessage = dryRun
    ? `Token cleanup dry run complete: ${totalRemoved} tokens would be removed`
    : `Token cleanup complete: ${totalRemoved} tokens removed`;
  
  console.log(completionMessage);

  return new Response(
    JSON.stringify({
      success: true,
      message: dryRun ? 'FCM token cleanup dry run completed' : 'FCM token cleanup completed',
      removedCount: totalRemoved,
      expectedCount: totalCount,
      cutoffDate: cutoffDateStr,
      daysInactive: CLEANUP_CONFIG.DAYS_INACTIVE,
      dryRun,
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}

// ============================================================================
// Start Server
// ============================================================================

createSimpleFunction(handleTokenCleanup, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
});
