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

// ============================================================================
// Types
// ============================================================================

interface PersonalizationRequest {
  action: 'save' | 'get' | 'skip';
  data?: {
    faith_journey?: 'new' | 'growing' | 'mature';
    seeking?: Array<'peace' | 'guidance' | 'knowledge' | 'relationships' | 'challenges'>;
    time_commitment?: '5min' | '15min' | '30min';
  };
}

interface PersonalizationData {
  faith_journey: string | null;
  seeking: string[];
  time_commitment: string | null;
  questionnaire_completed: boolean;
  questionnaire_skipped: boolean;
}

// ============================================================================
// Validation
// ============================================================================

const VALID_FAITH_JOURNEYS = ['new', 'growing', 'mature'];
const VALID_SEEKING = ['peace', 'guidance', 'knowledge', 'relationships', 'challenges'];
const VALID_TIME_COMMITMENTS = ['5min', '15min', '30min'];

function validatePersonalizationData(data: PersonalizationRequest['data']): void {
  if (!data) {
    throw new AppError('VALIDATION_ERROR', 'Personalization data is required', 400);
  }

  if (data.faith_journey && !VALID_FAITH_JOURNEYS.includes(data.faith_journey)) {
    throw new AppError(
      'VALIDATION_ERROR',
      `Invalid faith_journey. Must be one of: ${VALID_FAITH_JOURNEYS.join(', ')}`,
      400
    );
  }

  if (data.seeking) {
    if (!Array.isArray(data.seeking)) {
      throw new AppError('VALIDATION_ERROR', 'seeking must be an array', 400);
    }
    for (const item of data.seeking) {
      if (!VALID_SEEKING.includes(item)) {
        throw new AppError(
          'VALIDATION_ERROR',
          `Invalid seeking value: ${item}. Must be one of: ${VALID_SEEKING.join(', ')}`,
          400
        );
      }
    }
  }

  if (data.time_commitment && !VALID_TIME_COMMITMENTS.includes(data.time_commitment)) {
    throw new AppError(
      'VALIDATION_ERROR',
      `Invalid time_commitment. Must be one of: ${VALID_TIME_COMMITMENTS.join(', ')}`,
      400
    );
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

  // Upsert personalization data
  const { data: result, error } = await services.supabaseServiceClient
    .from('user_personalization')
    .upsert(
      {
        user_id: userId,
        faith_journey: data!.faith_journey || null,
        seeking: data!.seeking || [],
        time_commitment: data!.time_commitment || null,
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

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Personalization saved successfully',
      data: result,
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
    faith_journey: null,
    seeking: [],
    time_commitment: null,
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
