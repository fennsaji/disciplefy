// ============================================================================
// Mark Study Guide Complete Edge Function
// ============================================================================
// Marks a study guide as completed when user meets both conditions:
// 1. Spent at least 60 seconds on the page
// 2. Scrolled to the bottom of the content
//
// Completed guides are excluded from recommended topic push notifications

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { UserContext } from '../_shared/types/index.ts';
import { AppError } from '../_shared/utils/error-handler.ts';

// ============================================================================
// Types
// ============================================================================

interface MarkCompleteRequest {
  study_guide_id: string;
  time_spent_seconds: number;
  scrolled_to_bottom: boolean;
  /** When true, skips auto-completion condition checks (user manually tapped Complete Study) */
  is_manual?: boolean;
}

// ============================================================================
// Validation
// ============================================================================

function validateRequest(body: any): MarkCompleteRequest {
  if (!body) {
    throw new AppError('VALIDATION_ERROR', 'Request body is required', 400);
  }

  const { study_guide_id, time_spent_seconds, scrolled_to_bottom, is_manual } = body;

  // Validate study_guide_id
  if (!study_guide_id || typeof study_guide_id !== 'string') {
    throw new AppError(
      'VALIDATION_ERROR',
      'study_guide_id is required and must be a string',
      400
    );
  }

  // Validate time_spent_seconds
  if (typeof time_spent_seconds !== 'number' || time_spent_seconds < 0) {
    throw new AppError(
      'VALIDATION_ERROR',
      'time_spent_seconds must be a non-negative number',
      400
    );
  }

  // Validate scrolled_to_bottom
  if (typeof scrolled_to_bottom !== 'boolean') {
    throw new AppError(
      'VALIDATION_ERROR',
      'scrolled_to_bottom must be a boolean',
      400
    );
  }

  return {
    study_guide_id,
    time_spent_seconds,
    scrolled_to_bottom,
    is_manual: is_manual === true,
  };
}

function validateCompletionConditions(
  timeSpent: number,
  scrolledToBottom: boolean
): void {
  const MIN_TIME_SECONDS = 60; // 1 minute

  if (timeSpent < MIN_TIME_SECONDS) {
    throw new AppError(
      'COMPLETION_CONDITIONS_NOT_MET',
      `Minimum time requirement not met: ${timeSpent}s < ${MIN_TIME_SECONDS}s`,
      400
    );
  }

  if (!scrolledToBottom) {
    throw new AppError(
      'COMPLETION_CONDITIONS_NOT_MET',
      'User must scroll to the bottom of the study guide',
      400
    );
  }
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleMarkStudyGuideComplete(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  console.log('📋 [MARK_COMPLETE] Processing completion request...');

  // Get authenticated user (from JWT)
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError('UNAUTHORIZED', 'User must be authenticated', 401);
  }
  const userId = userContext.userId;

  // Parse and validate request body
  const body = await req.json();
  const { study_guide_id, time_spent_seconds, scrolled_to_bottom, is_manual } =
    validateRequest(body);

  console.log(`📋 [MARK_COMPLETE] Study guide: ${study_guide_id}`);
  console.log(`📋 [MARK_COMPLETE] Time spent: ${time_spent_seconds}s`);
  console.log(`📋 [MARK_COMPLETE] Scrolled to bottom: ${scrolled_to_bottom}`);
  console.log(`📋 [MARK_COMPLETE] Manual completion: ${is_manual}`);

  // Validate completion conditions only for auto-completion.
  // Manual taps of "Complete Study" always bypass these checks.
  if (!is_manual) {
    validateCompletionConditions(time_spent_seconds, scrolled_to_bottom);
  }

  const supabase = services.supabaseServiceClient;

  // Redact PII: Only log last 4 characters of userId for debugging
  const redactedUserId = userId ? `***${userId.slice(-4)}` : '***';

  // Verify user owns this study guide
  const { data: userGuide, error: ownershipError } = await supabase
    .from('user_study_guides')
    .select('id, study_guide_id, completed_at, study_guides(input_value, language)')
    .eq('user_id', userId)
    .eq('study_guide_id', study_guide_id)
    .maybeSingle();

  if (ownershipError) {
    console.error('📋 [MARK_COMPLETE] Ownership check error:', ownershipError);
    throw new AppError(
      'DATABASE_ERROR',
      `Failed to verify guide ownership: ${ownershipError.message}`,
      500
    );
  }

  if (!userGuide) {
    console.warn(
      `📋 [MARK_COMPLETE] User ${redactedUserId} does not own guide ${study_guide_id}`
    );
    throw new AppError(
      'NOT_FOUND',
      'Study guide not found or you do not have permission to mark it complete',
      404
    );
  }

  // Check if already completed
  if (userGuide.completed_at) {
    console.log(
      `📋 [MARK_COMPLETE] Guide already completed at: ${userGuide.completed_at}`
    );
    return new Response(
      JSON.stringify({
        success: true,
        message: 'Study guide already marked as complete',
        completed_at: userGuide.completed_at,
        already_completed: true,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }

  // Mark as complete
  const now = new Date().toISOString();
  const { error: updateError } = await supabase
    .from('user_study_guides')
    .update({
      completed_at: now,
      time_spent_seconds,
      scrolled_to_bottom,
      updated_at: now,
    })
    .eq('id', userGuide.id);

  if (updateError) {
    console.error('📋 [MARK_COMPLETE] Update error:', updateError);
    throw new AppError(
      'DATABASE_ERROR',
      `Failed to mark guide as complete: ${updateError.message}`,
      500
    );
  }

  console.log(
    `✅ [MARK_COMPLETE] Successfully marked guide as complete at ${now}`
  );

  // Record learning-path topic progress for this completion.
  //
  // The client only reports topic progress when the guide was opened through a
  // route that carries `topic_id` (learning path, fellowship lesson,
  // notification). Guides finished from Saved, Recent, Continue, the generate
  // flow or a shared link used to leave `user_topic_progress` untouched, so a
  // finished lesson still counted as zero in fellowship and path progress.
  // Resolving the topic here makes the record entry-point independent. The
  // RPC only awards XP on the first completion, so it is safe alongside the
  // client's own call.
  await recordTopicProgress(
    supabase,
    userId,
    (userGuide as unknown as GuideWithSource).study_guides,
    time_spent_seconds
  );

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Study guide marked as complete',
      completed_at: now,
      time_spent_seconds,
      scrolled_to_bottom,
      already_completed: false,
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}


// ============================================================================
// Topic progress
// ============================================================================

interface GuideWithSource {
  study_guides?: { input_value?: string | null; language?: string | null } | null;
}

/**
 * Best-effort: map the completed guide back to the recommended topic it was
 * generated from and mark that topic complete. Never fails the request — the
 * guide is already marked complete by the time this runs.
 */
async function recordTopicProgress(
  supabase: ServiceContainer['supabaseServiceClient'],
  userId: string,
  guide: GuideWithSource['study_guides'],
  timeSpentSeconds: number
): Promise<void> {
  try {
    const inputValue = guide?.input_value;
    if (!inputValue) return;

    const { data: topicId, error: resolveError } = await supabase.rpc(
      'resolve_topic_id_for_guide',
      { p_input_value: inputValue, p_language: guide?.language ?? 'en' }
    );

    if (resolveError) {
      console.warn('📋 [MARK_COMPLETE] Topic resolve failed:', resolveError.message);
      return;
    }
    if (!topicId) return;

    const { error: progressError } = await supabase.rpc('complete_topic_progress', {
      p_user_id: userId,
      p_topic_id: topicId,
      p_time_spent_seconds: timeSpentSeconds ?? 0,
    });

    if (progressError) {
      console.warn('📋 [MARK_COMPLETE] Topic progress failed:', progressError.message);
      return;
    }
    console.log(`📋 [MARK_COMPLETE] Topic progress recorded for topic ${topicId}`);
  } catch (err) {
    console.warn(
      '📋 [MARK_COMPLETE] Topic progress skipped:',
      err instanceof Error ? err.message : 'unknown error'
    );
  }
}

// ============================================================================
// Start Server
// ============================================================================

createAuthenticatedFunction(handleMarkStudyGuideComplete, {
  allowedMethods: ['POST'],
  enableAnalytics: false,
});
