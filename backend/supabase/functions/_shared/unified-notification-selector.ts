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
  /**
   * Learning path the topic belongs to, when it belongs to one. The app taps
   * through to this page: it cannot open the guide itself from a push, because
   * the study guide route has no fetch-by-id path.
   */
  pathId?: string;
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
    const incompleteGuide = await selectGuideToRemindAbout(supabase, userId);

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
 * How many times a single incomplete guide may be reminded about before it is
 * given up on. Without a cap, one guide the user never finishes pins the
 * notification to that topic forever and starves the "For You" fallback.
 */
const MAX_CONTINUE_REMINDERS = 3;

/**
 * Ignore incomplete guides older than this. A guide abandoned months ago is not
 * something the user intends to come back to.
 */
const MAX_GUIDE_AGE_DAYS = 30;

/**
 * Picks the incomplete study guide to remind the user about.
 *
 * Guides are only eligible once they are a day old (so a guide started today
 * isn't nagged about) and until they are MAX_GUIDE_AGE_DAYS old or have been
 * reminded about MAX_CONTINUE_REMINDERS times.
 *
 * Selection prefers the LEAST RECENTLY reminded guide — never-reminded first —
 * so a user with several unfinished guides sees them rotate instead of
 * receiving the same one every day.
 */
async function selectGuideToRemindAbout(
  supabase: SupabaseClient,
  userId: string
): Promise<IncompleteGuide | null> {
  // Only consider guides created more than 1 day ago
  const oneDayAgo = new Date();
  oneDayAgo.setDate(oneDayAgo.getDate() - 1);

  const oldestAllowed = new Date();
  oldestAllowed.setDate(oldestAllowed.getDate() - MAX_GUIDE_AGE_DAYS);

  const { data: guides, error } = await supabase
    .from('user_study_guides')
    .select(`
      id,
      time_spent_seconds,
      created_at,
      continue_reminder_count,
      last_continue_reminder_at,
      study_guides!inner(
        topic_id,
        input_type,
        input_value
      )
    `)
    .eq('user_id', userId)
    .is('completed_at', null)
    .lte('created_at', oneDayAgo.toISOString())
    .gte('created_at', oldestAllowed.toISOString())
    .lt('continue_reminder_count', MAX_CONTINUE_REMINDERS)
    // Filter to topic guides in the query, not after LIMIT — otherwise a
    // scripture guide at the front of the queue would abort the whole
    // selection and skip an eligible topic guide behind it.
    .eq('study_guides.input_type', 'topic')
    // Least recently reminded first; never-reminded guides sort ahead of all.
    .order('last_continue_reminder_at', { ascending: true, nullsFirst: true })
    .order('created_at', { ascending: true }) // Tie-break: oldest first
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

  if (!studyGuide) {
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
 * Records that a "Continue Your Study" reminder was sent for a guide.
 *
 * MUST be called after a successful send: the selector's repeat cap and
 * least-recently-reminded rotation both read these columns, so without this the
 * same guide would keep being chosen every day.
 *
 * Best-effort — a failure here must not fail the notification that was already
 * delivered.
 */
export async function recordContinueLearningReminder(
  supabaseUrl: string,
  supabaseServiceKey: string,
  guideId: string
): Promise<void> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  const { error } = await supabase.rpc('increment_continue_reminder', {
    p_guide_id: guideId,
  });

  if (error) {
    console.error(
      `[UnifiedSelector] Failed to record continue reminder for guide ${guideId}:`,
      error.message
    );
  }
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

  const pathId = guide.topic_id
    ? await getLearningPathIdForTopic(supabaseUrl, supabaseServiceKey, guide.topic_id)
    : null;

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
      ...(pathId ? { pathId } : {}),
    },
  };
}

/**
 * Finds the learning path a topic belongs to, if any.
 *
 * Used so a "Continue Your Study" tap can land on that path's page. Returns
 * null when the topic is standalone or the lookup fails — the app then falls
 * back to the Saved/Recent list rather than failing the notification.
 */
async function getLearningPathIdForTopic(
  supabaseUrl: string,
  supabaseServiceKey: string,
  topicId: string
): Promise<string | null> {
  try {
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const { data, error } = await supabase
      .from('learning_path_topics')
      .select('learning_path_id')
      .eq('topic_id', topicId)
      .order('position', { ascending: true })
      .limit(1)
      .maybeSingle();

    if (error) {
      console.error('[UnifiedSelector] Learning path lookup failed:', error.message);
      return null;
    }

    return data?.learning_path_id ?? null;
  } catch (error) {
    console.error('[UnifiedSelector] Learning path lookup threw:', formatError(error));
    return null;
  }
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
