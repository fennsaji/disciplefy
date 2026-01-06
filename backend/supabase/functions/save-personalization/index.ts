/**
 * Save Personalization Edge Function
 *
 * Saves user questionnaire responses for personalized topic recommendations
 * Part of the "For You" personalization feature
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { UserContext } from '../_shared/types/index.ts';
import { AppError } from '../_shared/utils/error-handler.ts';
import {
  calculatePathScores,
  validateQuestionnaireResponses,
  getScoringResultsSummary,
  type QuestionnaireResponses,
  type LearningPath,
  type ValidationResult,
} from '../_shared/personalization/scoring-algorithm.ts';

// ============================================================================
// Types
// ============================================================================

interface PersonalizationRequest {
  action: 'save' | 'get' | 'skip';
  data?: QuestionnaireResponses;
}

interface PersonalizationData {
  faith_stage: string | null;
  spiritual_goals: string[];
  time_availability: string | null;
  learning_style: string | null;
  life_stage_focus: string | null;
  biggest_challenge: string | null;
  scoring_results: Record<string, unknown> | null;
  questionnaire_completed: boolean;
  questionnaire_skipped: boolean;
}

// ============================================================================
// Validation
// ============================================================================

function validatePersonalizationData(data: PersonalizationRequest['data']): void {
  if (!data) {
    throw new AppError('VALIDATION_ERROR', 'Personalization data is required', 400);
  }

  // Use scoring algorithm's validation
  const validationResult = validateQuestionnaireResponses(data);
  if (!validationResult.isValid) {
    throw new AppError('VALIDATION_ERROR', validationResult.errors.join(', '), 400);
  }
}

// ============================================================================
// Handlers
// ============================================================================

async function savePersonalization(
  data: PersonalizationRequest['data'],
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  validatePersonalizationData(data);

  // Fetch all available learning paths
  const { data: learningPaths, error: pathsError } = await services.supabaseServiceClient
    .from('learning_paths')
    .select('id, slug, title, disciple_level, recommended_mode, is_featured, display_order')
    .eq('is_active', true)
    .order('display_order', { ascending: true });

  if (pathsError) {
    console.error('Failed to fetch learning paths:', pathsError);
    throw new AppError('DATABASE_ERROR', 'Failed to fetch learning paths', 500);
  }

  // Fetch user's completed paths
  const { data: completedPaths, error: completedError } = await services.supabaseServiceClient
    .from('user_learning_path_progress')
    .select('learning_path_id')
    .eq('user_id', userId)
    .not('completed_at', 'is', null);

  if (completedError && completedError.code !== 'PGRST116') {
    console.error('Failed to fetch completed paths:', completedError);
    throw new AppError('DATABASE_ERROR', 'Failed to fetch completed paths', 500);
  }

  const completedPathIds = (completedPaths || []).map((p) => p.learning_path_id);

  // Calculate path scores using scoring algorithm
  const scoredPaths = calculatePathScores(
    data as QuestionnaireResponses,
    learningPaths as LearningPath[],
    completedPathIds
  );

  if (!scoredPaths || scoredPaths.length === 0) {
    throw new AppError('VALIDATION_ERROR', 'No learning paths available for scoring', 400);
  }

  // Get scoring summary for analytics
  const topPath = scoredPaths[0]; // First path is highest scored
  const scoringSummary = getScoringResultsSummary(topPath, scoredPaths);

  // Upsert personalization data with scoring results
  const { data: result, error } = await services.supabaseServiceClient
    .from('user_personalization')
    .upsert(
      {
        user_id: userId,
        faith_stage: data!.faith_stage,
        spiritual_goals: data!.spiritual_goals,
        time_availability: data!.time_availability,
        learning_style: data!.learning_style,
        life_stage_focus: data!.life_stage_focus,
        biggest_challenge: data!.biggest_challenge,
        scoring_results: scoringSummary,
        questionnaire_completed: true,
        questionnaire_skipped: false,
        updated_at: new Date().toISOString(),
      },
      {
        onConflict: 'user_id',
      }
    )
    .select('*')
    .single();

  if (error) {
    console.error('Failed to save personalization:', error);
    throw new AppError('DATABASE_ERROR', 'Failed to save personalization', 500);
  }

  // Return response with top recommendation
  return new Response(
    JSON.stringify({
      success: true,
      message: 'Personalization saved successfully',
      data: result,
      recommendation: scoredPaths.length > 0 ? scoredPaths[0] : null,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

async function getPersonalization(
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const { data, error } = await services.supabaseServiceClient
    .from('user_personalization')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (error && error.code !== 'PGRST116') {
    // PGRST116 = no rows found, which is fine
    console.error('Failed to get personalization:', error);
    throw new AppError('DATABASE_ERROR', 'Failed to retrieve personalization', 500);
  }

  const personalization: PersonalizationData = data || {
    faith_stage: null,
    spiritual_goals: [],
    time_availability: null,
    learning_style: null,
    life_stage_focus: null,
    biggest_challenge: null,
    scoring_results: null,
    questionnaire_completed: false,
    questionnaire_skipped: false,
  };

  return new Response(
    JSON.stringify({
      success: true,
      data: personalization,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

async function skipPersonalization(
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  // Upsert with skipped flag
  const { data: result, error } = await services.supabaseServiceClient
    .from('user_personalization')
    .upsert(
      {
        user_id: userId,
        questionnaire_completed: false,
        questionnaire_skipped: true,
        updated_at: new Date().toISOString(),
      },
      {
        onConflict: 'user_id',
      }
    )
    .select('*')
    .single();

  if (error) {
    console.error('Failed to save skip status:', error);
    throw new AppError('DATABASE_ERROR', 'Failed to save skip status', 500);
  }

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Questionnaire skipped',
      data: result,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleSavePersonalization(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401);
  }

  // Validate userId is present (defensive check)
  const userId = userContext.userId;
  if (!userId) {
    throw new AppError('UNAUTHORIZED', 'User ID not found', 401);
  }

  // Parse request body with error handling for malformed JSON
  let body: PersonalizationRequest;
  try {
    body = await req.json();
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Invalid JSON in request body', 400);
  }

  if (!body.action) {
    throw new AppError('VALIDATION_ERROR', 'Action is required', 400);
  }

  switch (body.action) {
    case 'save':
      return savePersonalization(body.data, services, userId);

    case 'get':
      return getPersonalization(services, userId);

    case 'skip':
      return skipPersonalization(services, userId);

    default:
      throw new AppError('VALIDATION_ERROR', 'Invalid action. Must be: save, get, or skip', 400);
  }
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createAuthenticatedFunction(handleSavePersonalization, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000,
});
