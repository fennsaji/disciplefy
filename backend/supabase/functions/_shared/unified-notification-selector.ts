// ============================================================================
// Unified Notification Selector Service
// ============================================================================
// Intelligently selects the best notification for each user:
// 1. PRIORITY: Continue Learning (incomplete guides)
// 2. FALLBACK: Personalized For You recommendations
//
// This aligns push notifications with the "For You" section in the app

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { selectTopicsForYouWithLearningPath, getLocalizedTopicContent } from './topic-selector.ts';
import { formatError } from './utils/error-formatter.ts';

// ============================================================================
// Types
// ============================================================================

interface NotificationContent {
  type: 'continue_learning' | 'for_you';
  title: string;
  body: string;
  topicId: string;
  topicTitle: string;
  topicDescription: string;
  // Additional data for Continue Learning
  guideId?: string;
  progress?: number;
  timeSpent?: number;
}

interface UnifiedNotificationResult {
  success: boolean;
  notification?: NotificationContent;
  error?: string;
}

interface IncompleteGuide {
  id: string;
  topic_id: string | null;
  topic_title: string;
  topic_description: string;
  topic_category: string;
  time_spent_seconds: number;
  created_at: string;
}

// ============================================================================
// Notification Templates
// ============================================================================

const CONTINUE_LEARNING_TITLES: Record<string, string> = {
  en: '📚 Continue Your Study',
  hi: '📚 अपनी पढ़ाई जारी रखें',
  ml: '📚 നിങ്ങളുടെ പഠനം തുടരുക',
};

const CONTINUE_LEARNING_BODIES: Record<string, string> = {
  en: "Pick up where you left off:",
  hi: "जहाँ छोड़ा था वहीं से शुरू करें:",
  ml: "നിങ്ങൾ നിർത്തിയിടത്ത് നിന്ന് തുടരുക:",
};

const FOR_YOU_TITLES: Record<string, string> = {
  en: '💡 Recommended Topic',
  hi: '💡 अनुशंसित विषय',
  ml: '💡 ശുപാർശിത വിഷയം',
};

const FOR_YOU_INTROS: Record<string, string> = {
  en: 'Explore today:',
  hi: 'आज जानें:',
  ml: 'ഇന്ന് പര്യവേക്ഷണം ചെയ്യുക:',
};

// ============================================================================
// Main Selection Logic
// ============================================================================

/**
 * Selects the best notification for a user based on:
 * 1. PRIORITY: Incomplete study guides (Continue Learning)
 * 2. FALLBACK: Personalized topic recommendations (For You)
 *
 * This ensures push notifications align with the "For You" section,
 * which prioritizes incomplete guides before showing new recommendations.
 */
export async function selectNotificationForUser(
  supabaseUrl: string,
  supabaseServiceKey: string,
  userId: string,
  language: string
): Promise<UnifiedNotificationResult> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    console.log(`[UnifiedSelector] Selecting notification for user ${userId} (language: ${language})`);

    // Step 1: Check for incomplete guides (Continue Learning priority)
    const incompleteGuide = await getOldestIncompleteGuide(supabase, userId);

    if (incompleteGuide) {
      console.log(`[UnifiedSelector] Found incomplete guide: ${incompleteGuide.topic_title}`);
      return await createContinueLearningNotification(
        supabaseUrl,
        supabaseServiceKey,
        incompleteGuide,
        language
      );
    }

    console.log('[UnifiedSelector] No incomplete guides, fetching personalized For You topic...');

    // Step 2: Fallback to personalized For You recommendations
    return await createForYouNotification(
      supabaseUrl,
      supabaseServiceKey,
      userId,
      language
    );
  } catch (error) {
    return {
      success: false,
      error: formatError(error, 'Unified notification selection error'),
    };
  }
}

// ============================================================================
// Continue Learning Logic
// ============================================================================

/**
 * Gets the oldest incomplete study guide for a user
 * Prioritizes guides created more than 1 day ago to avoid spamming
 * new guides created today
 */
async function getOldestIncompleteGuide(
  supabase: SupabaseClient,
  userId: string
): Promise<IncompleteGuide | null> {
  // Only consider guides created more than 1 day ago
  const oneDayAgo = new Date();
  oneDayAgo.setDate(oneDayAgo.getDate() - 1);

  const { data: guides, error } = await supabase
    .from('user_study_guides')
    .select(`
      id,
      time_spent_seconds,
      created_at,
      study_guides!inner(
        topic_id,
        input_type,
        input_value
      )
    `)
    .eq('user_id', userId)
    .is('completed_at', null)
    .lte('created_at', oneDayAgo.toISOString())
    .order('created_at', { ascending: true }) // Oldest first
    .limit(1);

  if (error) {
    console.error('[UnifiedSelector] Error fetching incomplete guides:', error);
    return null;
  }

  if (!guides || guides.length === 0) {
    return null;
  }

  const guide = guides[0];
  const studyGuide = guide.study_guides as any;

  // Ensure we have topic information
  if (!studyGuide || studyGuide.input_type !== 'topic') {
    return null;
  }

  // If we have a topic_id, fetch the recommended_topics data for title/description
  let topicTitle = studyGuide.input_value; // Default to user's input
  let topicDescription = '';
  let topicCategory = '';

  if (studyGuide.topic_id) {
    const { data: topicData } = await supabase
      .from('recommended_topics')
      .select('title, description, category')
      .eq('id', studyGuide.topic_id)
      .single();

    if (topicData) {
      topicTitle = topicData.title || topicTitle;
      topicDescription = topicData.description || '';
      topicCategory = topicData.category || '';
    }
  }

  return {
    id: guide.id,
    topic_id: studyGuide.topic_id,
    topic_title: topicTitle,
    topic_description: topicDescription,
    topic_category: topicCategory,
    time_spent_seconds: guide.time_spent_seconds || 0,
    created_at: guide.created_at,
  };
}

/**
 * Creates a Continue Learning notification for an incomplete guide
 */
async function createContinueLearningNotification(
  supabaseUrl: string,
  supabaseServiceKey: string,
  guide: IncompleteGuide,
  language: string
): Promise<UnifiedNotificationResult> {
  // Get localized topic content if we have a topic_id
  let topicTitle = guide.topic_title;
  let topicDescription = guide.topic_description;

  if (guide.topic_id) {
    try {
      const localizedContent = await getLocalizedTopicContent(
        supabaseUrl,
        supabaseServiceKey,
        {
          id: guide.topic_id,
          title: guide.topic_title,
          description: guide.topic_description,
          category: guide.topic_category,
          display_order: 0,
          is_active: true,
        },
        language
      );
      topicTitle = localizedContent.title;
      topicDescription = localizedContent.description;
    } catch (error) {
      console.error('[UnifiedSelector] Error fetching localized content:', error);
      // Continue with original title/description
    }
  }

  const title = CONTINUE_LEARNING_TITLES[language] || CONTINUE_LEARNING_TITLES.en;
  const bodyIntro = CONTINUE_LEARNING_BODIES[language] || CONTINUE_LEARNING_BODIES.en;
  const body = `${bodyIntro} ${topicTitle}`;

  return {
    success: true,
    notification: {
      type: 'continue_learning',
      title,
      body,
      topicId: guide.topic_id || '',
      topicTitle,
      topicDescription,
      guideId: guide.id,
      timeSpent: guide.time_spent_seconds,
    },
  };
}

// ============================================================================
// For You Logic
// ============================================================================

/**
 * Creates a personalized For You notification using the same algorithm
 * as the For You section in the app
 */
async function createForYouNotification(
  supabaseUrl: string,
  supabaseServiceKey: string,
  userId: string,
  language: string
): Promise<UnifiedNotificationResult> {
  // Use the same logic as the For You endpoint
  const result = await selectTopicsForYouWithLearningPath(
    supabaseUrl,
    supabaseServiceKey,
    userId,
    1 // We only need 1 topic for the notification
  );

  if (!result.success || !result.topics || result.topics.length === 0) {
    return {
      success: false,
      error: result.error || 'No topics available for For You notification',
    };
  }

  const topic = result.topics[0];

  // Get localized content
  const localizedContent = await getLocalizedTopicContent(
    supabaseUrl,
    supabaseServiceKey,
    topic,
    language
  );

  const title = FOR_YOU_TITLES[language] || FOR_YOU_TITLES.en;
  const intro = FOR_YOU_INTROS[language] || FOR_YOU_INTROS.en;
  const body = `${intro} ${localizedContent.title}`;

  return {
    success: true,
    notification: {
      type: 'for_you',
      title,
      body,
      topicId: topic.id,
      topicTitle: localizedContent.title,
      topicDescription: localizedContent.description,
    },
  };
}
