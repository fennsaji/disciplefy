/**
 * Topics For You Edge Function
 *
 * Returns personalized topic recommendations for the "For You" section
 * Part of the home screen personalization feature
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { UserContext } from '../_shared/types/index.ts';
import { AppError } from '../_shared/utils/error-handler.ts';
import { selectTopicsForYou, getLocalizedTopicContent } from '../_shared/topic-selector.ts';

// ============================================================================
// Types
// ============================================================================

interface TopicsForYouRequest {
  language?: string;
  limit?: number;
}

interface LocalizedTopic {
  id: string;
  title: string;
  description: string;
  category: string;
  display_order: number;
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleTopicsForYou(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required', 401);
  }

  const userId = userContext.userId!;

  // Parse request body (can be empty for GET-like behavior)
  let body: TopicsForYouRequest = {};
  try {
    const text = await req.text();
    if (text) {
      body = JSON.parse(text);
    }
  } catch {
    // Empty body is fine
  }

  const language = body.language || 'en';
  const limit = Math.min(Math.max(body.limit || 4, 1), 10); // 1-10 topics

  // Get personalized topics
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const result = await selectTopicsForYou(supabaseUrl, supabaseServiceKey, userId, limit);

  if (!result.success) {
    throw new AppError('INTERNAL_ERROR', result.error || 'Failed to fetch topics', 500);
  }

  // Localize topics if needed
  const localizedTopics: LocalizedTopic[] = [];

  for (const topic of result.topics || []) {
    const localized = await getLocalizedTopicContent(
      supabaseUrl,
      supabaseServiceKey,
      topic,
      language
    );

    localizedTopics.push({
      id: topic.id,
      title: localized.title,
      description: localized.description,
      category: topic.category,
      display_order: topic.display_order,
    });
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        topics: localizedTopics,
        hasCompletedQuestionnaire: result.hasCompletedQuestionnaire,
        totalAvailable: localizedTopics.length,
      },
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createAuthenticatedFunction(handleTopicsForYou, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 15000,
});
