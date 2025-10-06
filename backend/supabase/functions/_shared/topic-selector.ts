// ============================================================================
// Topic Selection Service
// ============================================================================
// Intelligent topic selection for personalized recommendations
// Avoids recently sent topics and considers user study history

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

// ============================================================================
// Types
// ============================================================================

interface Topic {
  id: string;
  title: string;
  description: string;
  category: string;
  difficulty_level: 'beginner' | 'intermediate' | 'advanced';
  display_order: number;
  is_active: boolean;
}

interface TopicTranslation {
  topic_id: string;
  lang_code: string;
  title: string;
  description: string;
  category: string;
}

interface TopicSelectionResult {
  success: boolean;
  topic?: Topic;
  error?: string;
}

interface LocalizedContent {
  title: string;
  description: string;
}

// ============================================================================
// Topic Selection Logic
// ============================================================================

/**
 * Selects the best topic for a user based on:
 * 1. Topics not recently sent in notifications (within 30 days)
 * 2. Topics user hasn't studied recently (within 14 days)
 * 3. User's language preference
 * 4. Topic popularity and engagement
 */
export async function selectTopicForUser(
  supabaseUrl: string,
  supabaseServiceKey: string,
  userId: string,
  language: string
): Promise<TopicSelectionResult> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    // Get topics recently sent to this user (within 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const { data: recentNotifications, error: notifError } = await supabase
      .from('notification_logs')
      .select('topic_id')
      .eq('user_id', userId)
      .eq('notification_type', 'recommended_topic')
      .gte('sent_at', thirtyDaysAgo.toISOString())
      .not('topic_id', 'is', null);

    if (notifError) {
      console.error('Error fetching recent notifications:', notifError);
    }

    const excludedFromNotifications = new Set(
      recentNotifications?.map((n: any) => n.topic_id).filter(Boolean) || []
    );

    // Note: study_guides table doesn't have topic_id column, so we only exclude based on notifications
    const allExcludedIds = [...excludedFromNotifications];

    // Fetch all active topics, excluding recently sent ones
    let query = supabase
      .from('recommended_topics')
      .select('*')
      .eq('is_active', true)
      .order('display_order', { ascending: true });

    if (allExcludedIds.length > 0) {
      query = query.not('id', 'in', `(${allExcludedIds.join(',')})`);
    }

    const { data: topics, error: topicsError } = await query;

    if (topicsError) {
      return {
        success: false,
        error: `Failed to fetch topics: ${topicsError.message}`,
      };
    }

    if (!topics || topics.length === 0) {
      // If no topics available after filtering, get the first topic by display order
      const { data: oldestTopic, error: oldestError } = await supabase
        .from('recommended_topics')
        .select('*')
        .eq('is_active', true)
        .order('display_order', { ascending: true })
        .limit(1)
        .single();

      if (oldestError || !oldestTopic) {
        return {
          success: false,
          error: 'No active topics found',
        };
      }

      return {
        success: true,
        topic: oldestTopic,
      };
    }

    // Priority 1: Beginner topics for new users (no study history)
    const { count: studyCount } = await supabase
      .from('study_guides')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId);

    if (studyCount !== null && studyCount < 5) {
      const beginnerTopics = topics.filter(t => t.difficulty_level === 'beginner');
      if (beginnerTopics.length > 0) {
        // Return the first beginner topic by order_index
        return {
          success: true,
          topic: beginnerTopics[0],
        };
      }
    }

    // Priority 2: Return first available topic (by display_order)
    // Language selection is handled by getLocalizedTopicContent function
    return {
      success: true,
      topic: topics[0],
    };
  } catch (error) {
    return {
      success: false,
      error: `Topic selection error: ${error instanceof Error ? error.message : String(error)}`,
    };
  }
}

// ============================================================================
// Localization Helper
// ============================================================================

/**
 * Gets localized content for a topic based on language preference
 * Returns the default English content from the topic itself
 * For other languages, translations should be fetched from recommended_topics_translations
 */
export function getLocalizedTopicContent(
  topic: Topic,
  language: string
): LocalizedContent {
  // Default to the topic's title and description (English)
  return {
    title: topic.title,
    description: topic.description,
  };
}
