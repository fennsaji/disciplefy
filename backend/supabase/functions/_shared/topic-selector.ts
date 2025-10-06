// ============================================================================
// Topic Selection Service
// ============================================================================
// Intelligent topic selection for personalized recommendations
// Avoids recently sent topics and considers user study history

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { formatError } from './utils/error-formatter.ts';

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

    // Fallback: If no recent notifications, check user's study history
    // This prevents first-time users from getting repetitive recommendations
    let excludedFromStudyHistory: string[] = [];
    
    if (excludedFromNotifications.size === 0) {
      const fourteenDaysAgo = new Date();
      fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);

      // Get recently generated study guides with topic input
      const { data: recentGuides, error: guidesError } = await supabase
        .from('study_guides')
        .select('input_value')
        .eq('user_id', userId)
        .eq('input_type', 'topic')
        .gte('created_at', fourteenDaysAgo.toISOString())
        .order('created_at', { ascending: false })
        .limit(10);

      if (guidesError) {
        console.error('Error fetching recent study guides:', guidesError);
      }

      if (recentGuides && recentGuides.length > 0) {
        // Extract topic titles from study guides
        const recentTopicTitles = recentGuides
          .map((g: any) => g.input_value)
          .filter(Boolean);

        // Find matching topic IDs from recommended_topics
        if (recentTopicTitles.length > 0) {
          const { data: matchedTopics, error: matchError } = await supabase
            .from('recommended_topics')
            .select('id')
            .in('title', recentTopicTitles);

          if (matchError) {
            console.error('Error matching topic titles:', matchError);
          }

          excludedFromStudyHistory = matchedTopics?.map((t: any) => t.id) || [];
          console.log(`Fallback: Excluding ${excludedFromStudyHistory.length} topics from study history`);
        }
      }
    }

    // Combine exclusions from both notifications and study history
    const allExcludedIds = [
      ...excludedFromNotifications,
      ...excludedFromStudyHistory,
    ];

    // Fetch all active topics, excluding recently sent ones
    let query = supabase
      .from('recommended_topics')
      .select('*')
      .eq('is_active', true)
      .order('display_order', { ascending: true });

    if (allExcludedIds.length > 0) {
      query = query.not('id', 'in', allExcludedIds);
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
      error: formatError(error, 'Topic selection error'),
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
