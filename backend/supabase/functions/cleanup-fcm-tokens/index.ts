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
  // Verify service role authentication
  const authHeader = req.headers.get('Authorization');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!authHeader || !authHeader.startsWith('Bearer ') || authHeader.replace('Bearer ', '') !== serviceRoleKey) {
    throw new AppError('UNAUTHORIZED', 'Service role authentication required', 401);
  }

  console.log('Starting FCM token cleanup process...');

  const supabase = services.supabaseServiceClient;

  // Calculate cutoff date (90 days ago)
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - CLEANUP_CONFIG.DAYS_INACTIVE);
  const cutoffDateStr = cutoffDate.toISOString();

  console.log(`Removing tokens last updated before: ${cutoffDateStr}`);

  // Count tokens to be removed
  const { count: totalCount, error: countError } = await supabase
    .from('user_notification_preferences')
    .select('*', { count: 'exact', head: true })
    .lt('updated_at', cutoffDateStr);

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
    // Fetch a batch of expired tokens
    const { data: expiredTokens, error: fetchError } = await supabase
      .from('user_notification_preferences')
      .select('user_id, fcm_token')
      .lt('updated_at', cutoffDateStr)
      .limit(CLEANUP_CONFIG.BATCH_SIZE);

    if (fetchError) {
      console.error(`Error fetching batch: ${fetchError.message}`);
      break;
    }

    if (!expiredTokens || expiredTokens.length === 0) {
      hasMore = false;
      break;
    }

    // Delete this batch
    const userIds = expiredTokens.map(t => t.user_id);
    const { error: deleteError } = await supabase
      .from('user_notification_preferences')
      .delete()
      .in('user_id', userIds);

    if (deleteError) {
      console.error(`Error deleting batch: ${deleteError.message}`);
      // Continue with next batch instead of failing completely
    } else {
      totalRemoved += expiredTokens.length;
      console.log(`Deleted batch of ${expiredTokens.length} tokens (total: ${totalRemoved}/${totalCount})`);
    }

    // Check if there are more tokens to process
    hasMore = expiredTokens.length === CLEANUP_CONFIG.BATCH_SIZE;
  }

  console.log(`Token cleanup complete: ${totalRemoved} tokens removed`);

  return new Response(
    JSON.stringify({
      success: true,
      message: 'FCM token cleanup completed',
      removedCount: totalRemoved,
      expectedCount: totalCount,
      cutoffDate: cutoffDateStr,
      daysInactive: CLEANUP_CONFIG.DAYS_INACTIVE,
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
