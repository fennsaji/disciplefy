/**
 * Save Personalization Edge Function (kept for older apps)
 *
 * The 6-step questionnaire was retired on 2026-10-10: the growth goal (first
 * run, Settings > Change my goal) is the only personalisation question, and
 * new apps write it with the set_my_growth_goal database function.
 *
 * Older apps still call this function with `save`, `get` and `skip`. It keeps
 * the same request and response shape for them:
 *   - save: validates and stores the answers (user_personalization), and sets
 *     the growth goal mapped from them (growth_goal_from_answers). It no
 *     longer changes the study mode or notification settings.
 *   - get:  the stored row, plus `growth_goal`.
 *   - skip: marks the questionnaire skipped (a finished one stays finished).
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { UserContext } from '../_shared/types/index.ts';
import { AppError } from '../_shared/utils/error-handler.ts';
import { growthGoalOrNull, loadGrowthGoal, type GrowthGoal } from '../_shared/personalization/next-paths.ts';
import {
  answersRow,
  responseData,
  skipChangesFor,
  validateQuestionnaireResponses,
  type QuestionnaireResponses,
} from './rules.ts';

interface PersonalizationRequest {
  action: 'save' | 'get' | 'skip';
  data?: QuestionnaireResponses;
}

/** Default row for a user who never answered (the shape older apps parse). */
const EMPTY_ROW = {
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

function json(body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

/**
 * Sets the goal mapped from the answers. Best effort: the answers are saved
 * either way, and the user can still pick a goal in a newer app.
 */
async function saveGoalFromAnswers(
  services: ServiceContainer,
  userId: string,
  data: QuestionnaireResponses,
): Promise<GrowthGoal | null> {
  const client = services.supabaseServiceClient;
  const { data: mapped, error } = await client.rpc('growth_goal_from_answers', {
    p_faith_stage: data.faith_stage,
    p_spiritual_goals: data.spiritual_goals,
    p_life_stage_focus: data.life_stage_focus,
    p_biggest_challenge: data.biggest_challenge,
  });
  const goal = growthGoalOrNull(mapped);
  if (error || !goal) {
    console.warn('[save-personalization] no goal from answers', { code: error?.code ?? 'none' });
    return null;
  }
  const { error: upsertError } = await client
    .from('user_growth_goals')
    .upsert(
      { user_id: userId, goal, source: 'questionnaire', updated_at: new Date().toISOString() },
      { onConflict: 'user_id' },
    );
  if (upsertError) {
    console.warn('[save-personalization] goal save failed', { code: upsertError.code });
    return null;
  }
  return goal;
}

async function savePersonalization(
  data: PersonalizationRequest['data'],
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const validation = validateQuestionnaireResponses(data);
  if (!validation.isValid) {
    throw new AppError('VALIDATION_ERROR', validation.errors.join(', '), 400);
  }
  const answers = data as QuestionnaireResponses;

  const { data: row, error } = await services.supabaseServiceClient
    .from('user_personalization')
    .upsert(answersRow(userId, answers, new Date().toISOString()), { onConflict: 'user_id' })
    .select('*')
    .single();

  if (error) {
    console.error('[save-personalization] save failed', { code: error.code });
    throw new AppError('DATABASE_ERROR', 'Failed to save personalization', 500);
  }

  const goal = await saveGoalFromAnswers(services, userId, answers);

  return json({
    success: true,
    message: 'Personalization saved successfully',
    data: responseData(row, goal),
    // Kept for older apps; recommendations now come from learning-paths.
    recommendation: null,
  });
}

async function getPersonalization(
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const [{ data, error }, goal] = await Promise.all([
    services.supabaseServiceClient
      .from('user_personalization')
      .select('*')
      .eq('user_id', userId)
      .maybeSingle(),
    loadGrowthGoal(services.supabaseServiceClient, userId),
  ]);

  if (error) {
    console.error('[save-personalization] read failed', { code: error.code });
    throw new AppError('DATABASE_ERROR', 'Failed to retrieve personalization', 500);
  }

  return json({ success: true, data: responseData(data ?? EMPTY_ROW, goal) });
}

async function skipPersonalization(
  services: ServiceContainer,
  userId: string
): Promise<Response> {
  const { data: existing, error: readError } = await services.supabaseServiceClient
    .from('user_personalization')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();

  if (readError) {
    console.error('[save-personalization] read before skip failed', { code: readError.code });
    throw new AppError('DATABASE_ERROR', 'Failed to save skip status', 500);
  }

  // A finished questionnaire stays finished (Retake, then Close or Skip).
  const changes = skipChangesFor(existing);
  if (!changes) {
    return json({ success: true, message: 'Questionnaire kept', data: existing });
  }

  const { data: result, error } = await services.supabaseServiceClient
    .from('user_personalization')
    .upsert(
      { user_id: userId, ...changes, updated_at: new Date().toISOString() },
      { onConflict: 'user_id' }
    )
    .select('*')
    .single();

  if (error) {
    console.error('[save-personalization] skip failed', { code: error.code });
    throw new AppError('DATABASE_ERROR', 'Failed to save skip status', 500);
  }

  return json({ success: true, message: 'Questionnaire skipped', data: result });
}

async function handleSavePersonalization(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401);
  }
  const userId = userContext.userId;
  if (!userId) {
    throw new AppError('UNAUTHORIZED', 'User ID not found', 401);
  }

  let body: PersonalizationRequest;
  try {
    body = await req.json();
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Invalid JSON in request body', 400);
  }

  switch (body?.action) {
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

createAuthenticatedFunction(handleSavePersonalization, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000,
});
