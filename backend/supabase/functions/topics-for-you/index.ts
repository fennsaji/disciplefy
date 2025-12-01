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
import { selectTopicsForYouWithLearningPath, getLocalizedTopicContent } from '../_shared/topic-selector.ts';

// ============================================================================
// Types
// ============================================================================

interface TopicsForYouRequest {
  language?: string;
  limit?: number;
  include_progress?: boolean;
}

interface LocalizedTopic {
  id: string;
  title: string;
  description: string;
  category: string;
  display_order: number;
  xp_value: number;
  progress?: TopicProgressData;
  // Learning path fields (optional - only present for learning path topics)
  learning_path_id?: string;
  learning_path_name?: string;
  position_in_path?: number;
  total_topics_in_path?: number;
}

interface SuggestedLearningPath {
  id: string;
  name: string;
  reason: 'active' | 'personalized' | 'default';
}

interface TopicProgressData {
  started_at: string | null;
  completed_at: string | null;
  time_spent_seconds: number;
  xp_earned: number;
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
  const includeProgress = body.include_progress !== false; // Default to true

  // Get personalized topics with learning path integration
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const result = await selectTopicsForYouWithLearningPath(supabaseUrl, supabaseServiceKey, userId, limit);

  if (!result.success) {
    throw new AppError('INTERNAL_ERROR', result.error || 'Failed to fetch topics', 500);
  }

  // Fetch progress data for all topics if requested
  let progressMap: Record<string, TopicProgressData> = {};

  if (includeProgress && result.topics && result.topics.length > 0) {
    const topicIds = result.topics.map((t: any) => t.id);

    const { data: progressData } = await services.supabaseServiceClient
      .from('user_topic_progress')
      .select('topic_id, started_at, completed_at, time_spent_seconds, xp_earned')
      .eq('user_id', userId)
      .in('topic_id', topicIds);

    if (progressData) {
      for (const p of progressData) {
        progressMap[p.topic_id] = {
          started_at: p.started_at,
          completed_at: p.completed_at,
          time_spent_seconds: p.time_spent_seconds || 0,
          xp_earned: p.xp_earned || 0,
        };
      }
    }
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

    const topicData: LocalizedTopic = {
      id: topic.id,
      title: localized.title,
      description: localized.description,
      category: topic.category,
      display_order: topic.display_order,
      xp_value: (topic as any).xp_value || 50,
    };

    // Add learning path fields if present
    if ('learning_path_id' in topic && topic.learning_path_id) {
      topicData.learning_path_id = topic.learning_path_id;
      topicData.learning_path_name = (topic as any).learning_path_name;
      topicData.position_in_path = (topic as any).position_in_path;
      topicData.total_topics_in_path = (topic as any).total_topics_in_path;
    }

    if (includeProgress && progressMap[topic.id]) {
      topicData.progress = progressMap[topic.id];
    }

    localizedTopics.push(topicData);
  }

  // Build response with optional suggested learning path
  const responseData: any = {
    topics: localizedTopics,
    hasCompletedQuestionnaire: result.hasCompletedQuestionnaire,
    totalAvailable: localizedTopics.length,
  };

  // Add suggested learning path info if available
  if (result.suggestedLearningPath) {
    responseData.suggestedLearningPath = result.suggestedLearningPath;
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: responseData,
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
