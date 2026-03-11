/**
 * Topic Progress Edge Function
 *
 * Manages user progress on study topics for the gamification system
 * Part of Phase 1: Foundation & Progress Tracking
 *
 * Actions:
 * - start: Mark a topic as started (when user opens it)
 * - complete: Mark a topic as completed and award XP
 * - update_time: Update time spent on a topic
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { UserContext } from '../_shared/types/index.ts';
import { AppError } from '../_shared/utils/error-handler.ts';
import {
  calculatePathScores,
  getScoringResultsSummary,
  type QuestionnaireResponses,
  type LearningPath as ScoringLearningPath,
} from '../_shared/personalization/scoring-algorithm.ts';

// ============================================================================
// Types
// ============================================================================

type ProgressAction = 'start' | 'complete' | 'update_time';

interface TopicProgressRequest {
  action: ProgressAction;
  topic_id: string;
  time_spent_seconds?: number;
}

interface StartProgressResponse {
  id: string;
  topic_id: string;
  started_at: string;
  created_at: string;
}

interface CompleteProgressResponse {
  progress_id: string;
  xp_earned: number;
  is_first_completion: boolean;
  topic_title: string;
  // Optional fellowship auto-advance fields populated when the group advances
  fellowship_advanced?: boolean;
  fellowship_id?: string;
  new_guide_index?: number;
  study_completed?: boolean;
}

interface UpdateTimeResponse {
  id: string;
  topic_id: string;
  time_spent_seconds: number;
  updated_at: string;
}

// ============================================================================
// Validation
// ============================================================================

function validateRequest(body: unknown): TopicProgressRequest {
  if (!body || typeof body !== 'object') {
    throw new AppError('INVALID_REQUEST', 'Request body is required', 400);
  }

  const request = body as Record<string, unknown>;

  // Validate action
  const validActions: ProgressAction[] = ['start', 'complete', 'update_time'];
  if (!request.action || !validActions.includes(request.action as ProgressAction)) {
    throw new AppError(
      'INVALID_PARAMETER',
      `Invalid action. Must be one of: ${validActions.join(', ')}`,
      400
    );
  }

  // Validate topic_id
  if (!request.topic_id || typeof request.topic_id !== 'string') {
    throw new AppError('INVALID_PARAMETER', 'topic_id is required and must be a string', 400);
  }

  // Validate UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(request.topic_id)) {
    throw new AppError('INVALID_PARAMETER', 'topic_id must be a valid UUID', 400);
  }

  // Validate time_spent_seconds if provided
  if (request.time_spent_seconds !== undefined) {
    if (typeof request.time_spent_seconds !== 'number' || request.time_spent_seconds < 0) {
      throw new AppError(
        'INVALID_PARAMETER',
        'time_spent_seconds must be a non-negative number',
        400
      );
    }
  }

  return {
    action: request.action as ProgressAction,
    topic_id: request.topic_id,
    time_spent_seconds: request.time_spent_seconds as number | undefined,
  };
}

// ============================================================================
// Action Handlers
// ============================================================================

async function handleStartProgress(
  services: ServiceContainer,
  userId: string,
  topicId: string
): Promise<StartProgressResponse> {
  const { data, error } = await services.supabaseServiceClient.rpc('start_topic_progress', {
    p_user_id: userId,
    p_topic_id: topicId,
  });

  if (error) {
    console.error('[topic-progress] Error starting progress:', error);
    throw new AppError('DATABASE_ERROR', `Failed to start topic progress: ${error.message}`, 500);
  }

  if (!data) {
    throw new AppError('DATABASE_ERROR', 'No data returned from start_topic_progress', 500);
  }

  return {
    id: data.id,
    topic_id: data.topic_id,
    started_at: data.started_at,
    created_at: data.created_at,
  };
}

async function handleCompleteProgress(
  services: ServiceContainer,
  userId: string,
  topicId: string,
  timeSpentSeconds: number = 0
): Promise<CompleteProgressResponse> {
  const { data, error } = await services.supabaseServiceClient.rpc('complete_topic_progress', {
    p_user_id: userId,
    p_topic_id: topicId,
    p_time_spent_seconds: timeSpentSeconds,
  });

  if (error) {
    console.error('[topic-progress] Error completing progress:', error);
    throw new AppError(
      'DATABASE_ERROR',
      `Failed to complete topic progress: ${error.message}`,
      500
    );
  }

  // RPC returns an array, get first row
  const result = Array.isArray(data) ? data[0] : data;

  if (!result) {
    throw new AppError('NOT_FOUND', 'Topic not found or progress record not found', 404);
  }

  return {
    progress_id: result.progress_id,
    xp_earned: result.xp_earned,
    is_first_completion: result.is_first_completion,
    topic_title: result.topic_title,
  };
}

async function handleUpdateTime(
  services: ServiceContainer,
  userId: string,
  topicId: string,
  timeSpentSeconds: number
): Promise<UpdateTimeResponse> {
  // Use atomic RPC for race-condition-free time update
  const { data, error } = await services.supabaseServiceClient.rpc('upsert_topic_time', {
    p_user_id: userId,
    p_topic_id: topicId,
    p_time_spent_seconds: timeSpentSeconds,
  });

  if (error) {
    console.error('[topic-progress] Error updating time:', error);
    throw new AppError('DATABASE_ERROR', `Failed to update time spent: ${error.message}`, 500);
  }

  // RPC returns an array, get first row
  const result = Array.isArray(data) ? data[0] : data;

  if (!result) {
    throw new AppError('DATABASE_ERROR', 'No data returned from upsert_topic_time', 500);
  }

  return {
    id: result.id,
    topic_id: result.topic_id,
    time_spent_seconds: result.time_spent_seconds,
    updated_at: result.updated_at,
  };
}

// ============================================================================
// Score Recalculation (GAP-03)
// ============================================================================

/**
 * Recalculates personalization scores after a topic is completed.
 *
 * Triggered when:
 *   1. A learning path was just completed (completed_at set in the last 10 seconds)
 *   2. The user's total completed topic count reaches a multiple of 10
 *
 * Non-fatal: errors are logged and swallowed so topic completion always succeeds.
 */
async function maybeTriggerScoreRecalculation(
  services: ServiceContainer,
  userId: string,
  isFirstCompletion: boolean
): Promise<void> {
  // Only recalculate on genuine first completions; repeat completions earn no XP
  // and don't change path progress, so they can't trigger path completion either.
  if (!isFirstCompletion) return;

  try {
    // Check 1: Was a learning path just completed (within the last 10 s)?
    // The DB trigger fires synchronously inside the complete_topic_progress RPC transaction,
    // so completed_at is already set by the time we reach this point.
    const { data: justCompletedPaths } = await services.supabaseServiceClient
      .from('user_learning_path_progress')
      .select('learning_path_id')
      .eq('user_id', userId)
      .not('completed_at', 'is', null)
      .gte('completed_at', new Date(Date.now() - 10_000).toISOString());

    const pathJustCompleted = (justCompletedPaths || []).length > 0;

    // Check 2: Total completed topics is a multiple of 10 (milestone recalculation)
    const { count: completedCount } = await services.supabaseServiceClient
      .from('user_topic_progress')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .not('completed_at', 'is', null);

    const isMilestone =
      typeof completedCount === 'number' && completedCount > 0 && completedCount % 10 === 0;

    if (!pathJustCompleted && !isMilestone) return;

    const triggerReason = pathJustCompleted ? 'path_completion' : 'topic_milestone';
    console.log(
      `[topic-progress] Score recalculation triggered (${triggerReason}) for user ${userId}`
    );

    // Fetch questionnaire answers
    const { data: personalization } = await services.supabaseServiceClient
      .from('user_personalization')
      .select(
        'faith_stage, spiritual_goals, time_availability, learning_style, life_stage_focus, biggest_challenge, questionnaire_completed'
      )
      .eq('user_id', userId)
      .single();

    if (!personalization?.questionnaire_completed || !personalization.faith_stage) {
      console.log('[topic-progress] No questionnaire data — skipping recalculation');
      return;
    }

    // Fetch all active learning paths
    const { data: allPaths } = await services.supabaseServiceClient
      .from('learning_paths')
      .select('id, slug, title, disciple_level, recommended_mode, is_featured, display_order')
      .eq('is_active', true)
      .order('display_order', { ascending: true });

    if (!allPaths || allPaths.length === 0) return;

    // Fetch all completed path IDs (the trigger has already set completed_at on any newly finished path)
    const { data: completedPaths } = await services.supabaseServiceClient
      .from('user_learning_path_progress')
      .select('learning_path_id')
      .eq('user_id', userId)
      .not('completed_at', 'is', null);

    const completedPathIds = (completedPaths || []).map((p) => p.learning_path_id);

    const responses: QuestionnaireResponses = {
      faith_stage: personalization.faith_stage as QuestionnaireResponses['faith_stage'],
      spiritual_goals: personalization.spiritual_goals || [],
      time_availability:
        personalization.time_availability as QuestionnaireResponses['time_availability'],
      learning_style: personalization.learning_style as QuestionnaireResponses['learning_style'],
      life_stage_focus:
        personalization.life_stage_focus as QuestionnaireResponses['life_stage_focus'],
      biggest_challenge:
        personalization.biggest_challenge as QuestionnaireResponses['biggest_challenge'],
    };

    const scoredPaths = calculatePathScores(
      responses,
      allPaths as ScoringLearningPath[],
      completedPathIds
    );

    if (!scoredPaths || scoredPaths.length === 0) return;

    const topPath = scoredPaths[0];
    const scoringSummary = getScoringResultsSummary(topPath, scoredPaths);

    const { error: updateError } = await services.supabaseServiceClient
      .from('user_personalization')
      .update({ scoring_results: scoringSummary, updated_at: new Date().toISOString() })
      .eq('user_id', userId);

    if (updateError) {
      console.warn('[topic-progress] Failed to update scoring_results:', updateError);
    } else {
      console.log(
        `[topic-progress] Score recalculation complete (${triggerReason}): top = ${topPath.pathTitle} (score: ${topPath.score})`
      );
    }
  } catch (err) {
    // Non-fatal — topic completion must always succeed
    console.warn('[topic-progress] Score recalculation error (non-fatal):', err);
  }
}

// ============================================================================
// Fellowship Auto-Advance
// ============================================================================

interface FellowshipAdvanceResult {
  fellowship_id: string
  new_guide_index: number
  study_completed: boolean
}

async function maybeTriggerFellowshipAutoAdvance(
  services: ServiceContainer,
  userId: string,
  topicId: string,
  isFirstCompletion: boolean,
): Promise<FellowshipAdvanceResult | null> {
  if (!isFirstCompletion) return null

  try {
    const db = services.supabaseServiceClient

    const { data: memberships } = await db
      .from('fellowship_members')
      .select('fellowship_id')
      .eq('user_id', userId)
      .eq('is_active', true)

    if (!memberships || memberships.length === 0) return null

    const fellowshipIds = memberships.map((m: { fellowship_id: string }) => m.fellowship_id)

    const { data: studies } = await db
      .from('fellowship_study')
      .select('id, fellowship_id, learning_path_id, current_guide_index')
      .in('fellowship_id', fellowshipIds)
      .is('completed_at', null)

    if (!studies || studies.length === 0) return null

    for (const study of studies) {
      const { data: topicRow } = await db
        .from('learning_path_topics')
        .select('id')
        .eq('learning_path_id', study.learning_path_id)
        .eq('position', study.current_guide_index)
        .maybeSingle()

      if (!topicRow || topicRow.id !== topicId) continue

      // Muted members are intentionally included — muting restricts posting only,
      // not study participation. All active members must complete to trigger advance.
      const { data: members } = await db
        .from('fellowship_members')
        .select('user_id')
        .eq('fellowship_id', study.fellowship_id)
        .eq('is_active', true)

      if (!members || members.length === 0) continue

      const memberUserIds = members.map((m: { user_id: string }) => m.user_id)

      const { count: completedCount } = await db
        .from('user_topic_progress')
        .select('id', { count: 'exact', head: true })
        .eq('topic_id', topicId)
        .in('user_id', memberUserIds)
        .not('completed_at', 'is', null)

      if (completedCount !== memberUserIds.length) continue

      const { count: totalTopics } = await db
        .from('learning_path_topics')
        .select('id', { count: 'exact', head: true })
        .eq('learning_path_id', study.learning_path_id)

      if (!totalTopics) continue

      const nextIndex = study.current_guide_index + 1
      const isComplete = nextIndex >= totalTopics

      const updateData = isComplete
        ? { completed_at: new Date().toISOString(), updated_at: new Date().toISOString() }
        : { current_guide_index: nextIndex, updated_at: new Date().toISOString() }

      const { data: updatedRows, error: updateError } = await db
        .from('fellowship_study')
        .update(updateData)
        .eq('id', study.id)
        .eq('current_guide_index', study.current_guide_index)
        .select('id')

      if (updateError) {
        console.warn('[topic-progress] Fellowship auto-advance update error (non-fatal):', updateError)
        continue
      }

      if (!updatedRows || updatedRows.length === 0) {
        // Optimistic lock lost — another concurrent request already advanced
        console.log(`[topic-progress] Fellowship ${study.fellowship_id} already advanced by concurrent request, skipping`)
        continue
      }

      console.log(
        `[topic-progress] Fellowship ${study.fellowship_id} auto-advanced to guide ${isComplete ? 'COMPLETE' : nextIndex}`
      )

      return {
        fellowship_id: study.fellowship_id,
        new_guide_index: isComplete ? study.current_guide_index : nextIndex,
        study_completed: isComplete,
      }
    }

    return null
  } catch (err) {
    console.warn('[topic-progress] Fellowship auto-advance error (non-fatal):', err)
    return null
  }
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleTopicProgress(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  // Require authentication
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401);
  }

  const userId = userContext.userId!;

  // Parse and validate request body
  const text = await req.text();
  if (!text) {
    throw new AppError('INVALID_REQUEST', 'Request body is required', 400);
  }

  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    throw new AppError('INVALID_REQUEST', 'Invalid JSON in request body', 400);
  }

  const request = validateRequest(body);

  // Route to appropriate handler based on action
  let result: StartProgressResponse | CompleteProgressResponse | UpdateTimeResponse;

  switch (request.action) {
    case 'start':
      result = await handleStartProgress(services, userId, request.topic_id);
      break;

    case 'complete': {
      result = await handleCompleteProgress(
        services,
        userId,
        request.topic_id,
        request.time_spent_seconds
      );
      await maybeTriggerScoreRecalculation(
        services,
        userId,
        (result as CompleteProgressResponse).is_first_completion
      );
      const fellowshipAdvance = await maybeTriggerFellowshipAutoAdvance(
        services,
        userId,
        request.topic_id,
        (result as CompleteProgressResponse).is_first_completion
      );
      if (fellowshipAdvance) {
        const typed = result as CompleteProgressResponse;
        typed.fellowship_advanced = true;
        typed.fellowship_id = fellowshipAdvance.fellowship_id;
        typed.new_guide_index = fellowshipAdvance.new_guide_index;
        typed.study_completed = fellowshipAdvance.study_completed;
      }
      break;
    }

    case 'update_time':
      if (request.time_spent_seconds === undefined) {
        throw new AppError(
          'INVALID_PARAMETER',
          'time_spent_seconds is required for update_time action',
          400
        );
      }
      result = await handleUpdateTime(
        services,
        userId,
        request.topic_id,
        request.time_spent_seconds
      );
      break;

    default:
      throw new AppError('INVALID_PARAMETER', 'Invalid action', 400);
  }

  // Log analytics
  await services.analyticsLogger.logEvent(
    `topic_progress_${request.action}`,
    {
      topic_id: request.topic_id,
      user_id: userId,
      time_spent_seconds: request.time_spent_seconds,
    },
    req.headers.get('x-forwarded-for')
  );

  return new Response(
    JSON.stringify({
      success: true,
      data: result,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createAuthenticatedFunction(handleTopicProgress, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000,
});
