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

    case 'complete':
      result = await handleCompleteProgress(
        services,
        userId,
        request.topic_id,
        request.time_spent_seconds
      );
      break;

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
