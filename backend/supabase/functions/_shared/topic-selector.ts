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
 * 2. Topics from completed guides (excluded forever)
 * 3. Topics user hasn't studied recently (within 14 days, incomplete only)
 * 4. Topic display order (ascending)
 *
 * COMPLETION TRACKING:
 * - Completed guides are ALWAYS excluded from recommendations (regardless of date)
 * - Completion is tracked via completed_at timestamp in user_study_guides table
 * - Ensures users never receive duplicate recommendations for completed topics
 *
 * HYBRID EXCLUSION STRATEGY (supports pre-migration and post-migration guides):
 * - Post-migration guides: Excluded by topic_id (UUID foreign key to recommended_topics)
 * - Pre-migration guides: Excluded by title/input_value matching (string comparison)
 *
 * This dual approach ensures backward compatibility with guides created before
 * the topic_id migration while maintaining accurate exclusion for new guides.
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

    // ALWAYS exclude completed guides (regardless of notification history)
    // Completed guides should never be recommended again
    const { data: completedGuides, error: completedError } = await supabase
      .from('user_study_guides')
      .select('study_guide_id, study_guides!inner(topic_id, input_type, input_value)')
      .eq('user_id', userId)
      .not('completed_at', 'is', null);

    if (completedError) {
      console.error('Error fetching completed study guides:', completedError);
    }

    let excludedFromCompleted: string[] = [];
    let excludedCompletedTitles: string[] = [];

    if (completedGuides && completedGuides.length > 0) {
      // Separate processing for guides with topic_id vs without
      for (const guide of completedGuides) {
        const studyGuide = guide.study_guides as any;

        if (studyGuide?.topic_id) {
          // Post-migration guide: exclude by topic_id
          excludedFromCompleted.push(studyGuide.topic_id);
        } else if (studyGuide?.input_type === 'topic' && studyGuide?.input_value) {
          // Pre-migration guide: exclude by title/input matching
          excludedCompletedTitles.push(studyGuide.input_value.toLowerCase().trim());
        }
      }

      // Deduplicate
      excludedFromCompleted = [...new Set(excludedFromCompleted)];
      excludedCompletedTitles = [...new Set(excludedCompletedTitles)];

      console.log(`Excluding ${excludedFromCompleted.length} completed topics by ID and ${excludedCompletedTitles.length} by title`);
    }

    // Fallback: If no recent notifications, check user's study history for recent incomplete guides
    // This prevents first-time users from getting repetitive recommendations
    let excludedFromStudyHistory: string[] = [];
    let excludedTitlesAndInputs: string[] = [];

    if (excludedFromNotifications.size === 0) {
      const fourteenDaysAgo = new Date();
      fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);

      // Get recently created incomplete guides (within 14 days)
      const { data: recentGuides, error: guidesError } = await supabase
        .from('user_study_guides')
        .select('study_guide_id, study_guides!inner(topic_id, input_type, input_value, created_at)')
        .eq('user_id', userId)
        .is('completed_at', null)
        .gte('study_guides.created_at', fourteenDaysAgo.toISOString())
        .order('study_guides.created_at', { ascending: false })
        .limit(10);

      if (guidesError) {
        console.error('Error fetching recent study guides:', guidesError);
      }

      if (recentGuides && recentGuides.length > 0) {
        // Separate processing for guides with topic_id vs without
        for (const guide of recentGuides) {
          const studyGuide = guide.study_guides as any;

          if (studyGuide?.topic_id) {
            // Post-migration guide: exclude by topic_id
            excludedFromStudyHistory.push(studyGuide.topic_id);
          } else if (studyGuide?.input_type === 'topic' && studyGuide?.input_value) {
            // Pre-migration guide: exclude by title/input matching
            excludedTitlesAndInputs.push(studyGuide.input_value.toLowerCase().trim());
          }
        }

        // Deduplicate
        excludedFromStudyHistory = [...new Set(excludedFromStudyHistory)];
        excludedTitlesAndInputs = [...new Set(excludedTitlesAndInputs)];

        console.log(`Fallback: Excluding ${excludedFromStudyHistory.length} recent incomplete topics by ID and ${excludedTitlesAndInputs.length} by title/input from study history`);
      }
    }

    // Combine exclusions from notifications, completed guides, and study history
    const allExcludedIds = [
      ...excludedFromNotifications,
      ...excludedFromCompleted,
      ...excludedFromStudyHistory,
    ];

    // Fetch all active topics, excluding recently sent ones
    let query = supabase
      .from('recommended_topics')
      .select('*')
      .eq('is_active', true)
      .order('display_order', { ascending: true });

    if (allExcludedIds.length > 0) {
      // Format: .not('id', 'in', '(uuid1,uuid2,uuid3)')
      // PostgREST expects parentheses around comma-separated values
      query = query.not('id', 'in', `(${allExcludedIds.join(',')})`);
    }

    const { data: topics, error: topicsError } = await query;

    if (topicsError) {
      return {
        success: false,
        error: `Failed to fetch topics: ${topicsError.message}`,
      };
    }

    // Further filter topics by title/input matching for pre-migration guides
    // Combine completed guide titles with recent incomplete guide titles
    const allExcludedTitles = [
      ...excludedCompletedTitles,
      ...excludedTitlesAndInputs,
    ];

    let filteredTopics = topics || [];
    if (allExcludedTitles.length > 0 && filteredTopics.length > 0) {
      filteredTopics = filteredTopics.filter(topic => {
        const topicTitle = topic.title.toLowerCase().trim();
        return !allExcludedTitles.includes(topicTitle);
      });

      console.log(`After title/input filtering: ${filteredTopics.length} topics remaining (excluded ${allExcludedTitles.length} titles)`);
    }

    if (!filteredTopics || filteredTopics.length === 0) {
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

    // Return first available topic (by display_order)
    // Language selection is handled by getLocalizedTopicContent function
    return {
      success: true,
      topic: filteredTopics[0],
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
 * Fetches translations from recommended_topics_translations table
 * Falls back to English if translation not found
 */
export async function getLocalizedTopicContent(
  supabaseUrl: string,
  supabaseServiceKey: string,
  topic: Topic,
  language: string
): Promise<LocalizedContent> {
  // If language is English, return original content
  if (language === 'en') {
    return {
      title: topic.title,
      description: topic.description,
    };
  }

  // Fetch translation from database
  const supabase = createClient(supabaseUrl, supabaseServiceKey);
  
  try {
    const { data: translation, error } = await supabase
      .from('recommended_topics_translations')
      .select('title, description')
      .eq('topic_id', topic.id)
      .eq('lang_code', language)
      .single();

    if (error) {
      console.error(`Translation fetch error for topic ${topic.id}, language ${language}:`, error);
      // Fallback to English
      return {
        title: topic.title,
        description: topic.description,
      };
    }

    if (translation) {
      return {
        title: translation.title,
        description: translation.description,
      };
    }

    // Fallback to English if no translation found
    return {
      title: topic.title,
      description: topic.description,
    };
  } catch (error) {
    console.error('Error fetching topic translation:', error);
    // Fallback to English
    return {
      title: topic.title,
      description: topic.description,
    };
  }
}
