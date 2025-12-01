/**
 * Continue Learning Edge Function
 *
 * Returns in-progress topics for the "Continue Learning" section
 * Part of Phase 1: Foundation & Progress Tracking
 *
 * Features:
 * - Returns topics the user has started but not completed
 * - Includes progress data (time spent, XP potential)
 * - Supports multi-language content
 * - Orders by most recently accessed
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { UserContext } from '../_shared/types/index.ts';
import { AppError } from '../_shared/utils/error-handler.ts';

// ============================================================================
// Types
// ============================================================================

interface ContinueLearningRequest {
  language?: string;
  limit?: number;
}

interface InProgressTopic {
  topic_id: string;
  topic_title: string;
  topic_description: string;
  topic_category: string;
  started_at: string;
  time_spent_seconds: number;
  xp_value: number;
  learning_path_id: string | null;
  learning_path_name: string | null;
  position_in_path: number | null;
  total_topics_in_path: number | null;
  topics_completed_in_path: number | null;
}

interface LocalizedInProgressTopic {
  topic_id: string;
  title: string;
  description: string;
  category: string;
  started_at: string;
  time_spent_seconds: number;
  xp_value: number;
  learning_path_id: string | null;
  learning_path_name: string | null;
  position_in_path: number | null;
  total_topics_in_path: number | null;
  topics_completed_in_path: number | null;
}

// ============================================================================
// Configuration
// ============================================================================

const DEFAULT_LANGUAGE = 'en';
const DEFAULT_LIMIT = 5;
const MAX_LIMIT = 10;

// ============================================================================
// Helper Functions
// ============================================================================

async function getLocalizedContent(
  services: ServiceContainer,
  topicId: string,
  language: string,
  fallbackTitle: string,
  fallbackDescription: string
): Promise<{ title: string; description: string }> {
  if (language === 'en') {
    return { title: fallbackTitle, description: fallbackDescription };
  }

  // Try to get localized content from recommended_topics_translations table
  // using lang_code column (not language_code)
  const { data: translation } = await services.supabaseServiceClient
    .from('recommended_topics_translations')
    .select('title, description')
    .eq('topic_id', topicId)
    .eq('lang_code', language)
    .single();

  if (translation) {
    return {
      title: translation.title || fallbackTitle,
      description: translation.description || fallbackDescription,
    };
  }

  return { title: fallbackTitle, description: fallbackDescription };
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleContinueLearning(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  // Require authentication
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401);
  }

  const userId = userContext.userId!;

  // Parse query parameters
  const url = new URL(req.url);
  const language = url.searchParams.get('language') || DEFAULT_LANGUAGE;
  const parsedLimit = parseInt(url.searchParams.get('limit') || '');
  const limitParam = Number.isNaN(parsedLimit) ? DEFAULT_LIMIT : parsedLimit;
  const limit = Math.max(1, Math.min(limitParam, MAX_LIMIT));

  // Get in-progress topics using the database function
  const { data: inProgressTopics, error } = await services.supabaseServiceClient.rpc(
    'get_in_progress_topics',
    {
      p_user_id: userId,
      p_limit: limit,
    }
  );

  if (error) {
    console.error('[continue-learning] Error fetching in-progress topics:', error);
    throw new AppError(
      'DATABASE_ERROR',
      `Failed to fetch in-progress topics: ${error.message}`,
      500
    );
  }

  // If no in-progress topics, return empty array
  if (!inProgressTopics || inProgressTopics.length === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          topics: [],
          total: 0,
        },
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  }

  // Localize content if needed
  const localizedTopics: LocalizedInProgressTopic[] = [];

  for (const topic of inProgressTopics) {
    const localized = await getLocalizedContent(
      services,
      topic.topic_id,
      language,
      topic.topic_title,
      topic.topic_description
    );

    localizedTopics.push({
      topic_id: topic.topic_id,
      title: localized.title,
      description: localized.description,
      category: topic.topic_category,
      started_at: topic.started_at,
      time_spent_seconds: topic.time_spent_seconds,
      xp_value: topic.xp_value,
      learning_path_id: topic.learning_path_id,
      learning_path_name: topic.learning_path_name,
      position_in_path: topic.position_in_path,
      total_topics_in_path: topic.total_topics_in_path,
      topics_completed_in_path: topic.topics_completed_in_path,
    });
  }

  // Log analytics
  await services.analyticsLogger.logEvent(
    'continue_learning_accessed',
    {
      user_id: userId,
      topics_count: localizedTopics.length,
      language,
    },
    req.headers.get('x-forwarded-for')
  );

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        topics: localizedTopics,
        total: localizedTopics.length,
      },
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createAuthenticatedFunction(handleContinueLearning, {
  allowedMethods: ['GET'],
  enableAnalytics: true,
  timeout: 15000,
});
