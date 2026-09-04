// ============================================================================
// Unified Notification Selector Service
// ============================================================================
// Intelligently selects the best notification for each user:
// 1. PRIORITY: Continue Learning (next topic in the user's most recently
//    active learning path)
// 2. FALLBACK: Personalized For You recommendations, rotating through
//    candidate paths so an ignored push doesn't repeat forever
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
}

interface UnifiedNotificationResult {
  success: boolean;
  notification?: NotificationContent;
  error?: string;
}

interface NextPathTopic {
  topic_id: string;
  topic_title: string;
  topic_description: string;
  topic_category: string;
  learning_path_id: string;
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
 * 1. PRIORITY: Next topic in an active learning path (Continue Learning)
 * 2. FALLBACK: Personalized topic recommendations (For You)
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

    // Step 1: Continue Learning priority — the next topic in whichever
    // active learning path the user read most recently.
    const nextTopic = await selectNextPathTopic(supabase, userId);

    if (nextTopic) {
      console.log(`[UnifiedSelector] Next topic in an active path: ${nextTopic.topic_title}`);
      return await createContinuePathNotification(
        supabaseUrl,
        supabaseServiceKey,
        nextTopic,
        language
      );
    }

    console.log('[UnifiedSelector] No active learning path, fetching personalized For You topic...');

    // Step 2: Fallback to personalized For You recommendations. Rotate
    // through the user's ranked candidate paths rather than always the top
    // match — otherwise a user who never starts anything gets the identical
    // notification forever (product decision, 4 Sept 2026).
    const rotatingTopic = await selectRotatingForYouTopic(supabase, userId);
    if (rotatingTopic) {
      return await createForYouNotificationFromTopic(
        supabaseUrl,
        supabaseServiceKey,
        rotatingTopic,
        language
      );
    }

    // No scoring data to rotate through (e.g. onboarding questionnaire never
    // completed) — same single-best-match selection as before.
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
 * Picks the next topic to suggest from the learning path the user is most
 * actively working through — three cases, per the product decision on
 * 4 Sept 2026:
 *
 *  1. No active (enrolled, uncompleted) path at all -> null, caller falls
 *     back to a personalized "For You" topic.
 *  2. One active path -> its next topic (user_learning_path_progress.
 *     current_topic_position, advanced by the app's own completion trigger
 *     each time a topic in the path is finished).
 *  3. Several active paths -> the one with the most recent last_activity_at
 *     ("the path the user read most recently"), not a rotation or a cap —
 *     the position naturally advances once they act on the suggestion, so
 *     there is nothing to rate-limit the way the old "incomplete guide"
 *     reminder needed to be.
 *
 * Mirrors the `next_in_path` CTE inside the get_in_progress_topics() SQL
 * function (20260721000003_update_learning_path_functions_for_visibility.sql)
 * — same is_active filters on both path and topic, same raw-position cursor
 * match against current_topic_position. That function returns several
 * candidates for the app's own "in progress" UI and is *not* ordered by
 * recency in its final result (DISTINCT ON collapses to topic_id order), so
 * it is not reused directly here; this is the narrower, single-path query
 * scenario 3 actually needs.
 */
async function selectNextPathTopic(
  supabase: SupabaseClient,
  userId: string
): Promise<NextPathTopic | null> {
  const { data: progress, error: progressError } = await supabase
    .from('user_learning_path_progress')
    .select('learning_path_id, current_topic_position, learning_paths!inner(is_active)')
    .eq('user_id', userId)
    .is('completed_at', null)
    .eq('learning_paths.is_active', true)
    .order('last_activity_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (progressError) {
    console.error('[UnifiedSelector] Error fetching active learning path progress:', progressError);
    return null;
  }

  if (!progress) {
    return null;
  }

  const { data: nextTopic, error: topicError } = await supabase
    .from('learning_path_topics')
    .select('topic_id, recommended_topics!inner(title, description, category, is_active)')
    .eq('learning_path_id', progress.learning_path_id)
    .eq('position', progress.current_topic_position)
    .eq('is_active', true)
    .eq('recommended_topics.is_active', true)
    .maybeSingle();

  if (topicError) {
    console.error('[UnifiedSelector] Error fetching next path topic:', topicError);
    return null;
  }

  if (!nextTopic) {
    // Path exhausted or the cursor's topic was hidden since — nothing valid
    // to suggest from this path.
    return null;
  }

  const topic = nextTopic.recommended_topics as unknown as {
    title: string;
    description: string;
    category: string;
  };

  return {
    topic_id: nextTopic.topic_id,
    topic_title: topic.title,
    topic_description: topic.description,
    topic_category: topic.category,
    learning_path_id: progress.learning_path_id,
  };
}

/**
 * Creates a Continue Learning notification for the next topic in an active
 * learning path.
 */
async function createContinuePathNotification(
  supabaseUrl: string,
  supabaseServiceKey: string,
  nextTopic: NextPathTopic,
  language: string
): Promise<UnifiedNotificationResult> {
  let topicTitle = nextTopic.topic_title;
  let topicDescription = nextTopic.topic_description;

  try {
    const localizedContent = await getLocalizedTopicContent(
      supabaseUrl,
      supabaseServiceKey,
      {
        id: nextTopic.topic_id,
        title: nextTopic.topic_title,
        description: nextTopic.topic_description,
        category: nextTopic.topic_category,
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

  const title = CONTINUE_LEARNING_TITLES[language] || CONTINUE_LEARNING_TITLES.en;
  const bodyIntro = CONTINUE_LEARNING_BODIES[language] || CONTINUE_LEARNING_BODIES.en;
  const body = `${bodyIntro} ${topicTitle}`;

  return {
    success: true,
    notification: {
      type: 'continue_learning',
      title,
      body,
      topicId: nextTopic.topic_id,
      topicTitle,
      topicDescription,
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

// ============================================================================
// Rotating For You Fallback
// ============================================================================

interface RotatingTopicCandidate {
  id: string;
  title: string;
  description: string;
  category: string;
}

/**
 * Picks a personalized "For You" topic that rotates through the user's
 * ranked candidate paths, instead of the single best match every time.
 *
 * Without this, `selectTopicsForYouWithLearningPath`'s priority-2 logic
 * always returns `scoring_results.allScores[0]` — deterministic, so a user
 * who never starts a path gets the identical push forever if they ignore it
 * (product decision, 4 Sept 2026).
 *
 * Walks the ranked candidates (best first), skipping any path whose first
 * topic has already been sent as a for_you/recommended_topic push. Once
 * every candidate has been tried, the cycle restarts from the top rather
 * than falling silent.
 *
 * Returns null when there's nothing to rotate through — no completed
 * questionnaire, or `scoring_results.allScores` missing/empty — so the
 * caller can fall back to the existing single-best-match selection
 * unchanged. That fallback also covers the (very unlikely) case of a
 * candidate path with no active topics.
 */
async function selectRotatingForYouTopic(
  supabase: SupabaseClient,
  userId: string
): Promise<RotatingTopicCandidate | null> {
  const { data: personalization, error: persError } = await supabase
    .from('user_personalization')
    .select('scoring_results')
    .eq('user_id', userId)
    .maybeSingle();

  if (persError) {
    console.error('[UnifiedSelector] Error fetching personalization for rotation:', persError);
    return null;
  }

  const allScores = (personalization?.scoring_results as { allScores?: { pathSlug: string }[] } | null)
    ?.allScores;
  if (!allScores || allScores.length === 0) {
    return null;
  }

  const [{ data: completedPaths }, { data: sentLogs }] = await Promise.all([
    supabase
      .from('user_learning_path_progress')
      .select('learning_path_id, learning_paths!inner(slug)')
      .eq('user_id', userId)
      .not('completed_at', 'is', null),
    supabase
      .from('notification_logs')
      .select('topic_id')
      .eq('user_id', userId)
      .in('notification_type', ['for_you', 'recommended_topic'])
      .not('topic_id', 'is', null),
  ]);

  const completedSlugs = new Set<string>(
    (completedPaths || []).map((p: any) => p.learning_paths?.slug).filter(Boolean)
  );
  const alreadySentTopicIds = new Set<string>(
    (sentLogs || []).map((l: any) => l.topic_id).filter(Boolean)
  );

  const candidateSlugs = allScores
    .map((s) => s.pathSlug)
    .filter((slug) => slug && !completedSlugs.has(slug));

  if (candidateSlugs.length === 0) {
    return null;
  }

  let firstCandidateTopic: RotatingTopicCandidate | null = null;

  for (const slug of candidateSlugs) {
    const { data: path } = await supabase
      .from('learning_paths')
      .select('id')
      .eq('slug', slug)
      .eq('is_active', true)
      .maybeSingle();
    if (!path) continue;

    const { data: firstTopic } = await supabase
      .from('learning_path_topics')
      .select('topic_id, recommended_topics!inner(title, description, category, is_active)')
      .eq('learning_path_id', path.id)
      .eq('position', 0)
      .eq('is_active', true)
      .eq('recommended_topics.is_active', true)
      .maybeSingle();
    if (!firstTopic) continue;

    const rt = firstTopic.recommended_topics as unknown as {
      title: string;
      description: string;
      category: string;
    };
    const candidate: RotatingTopicCandidate = {
      id: firstTopic.topic_id,
      title: rt.title,
      description: rt.description,
      category: rt.category,
    };

    if (!firstCandidateTopic) {
      // Kept as the reset target if the whole cycle has already been sent.
      firstCandidateTopic = candidate;
    }

    if (!alreadySentTopicIds.has(candidate.id)) {
      return candidate;
    }
  }

  // Every candidate in this cycle has already been sent — restart from the
  // top rather than returning null (which would fall through to the
  // single-best-match path and re-send the exact same thing anyway).
  return firstCandidateTopic;
}

async function createForYouNotificationFromTopic(
  supabaseUrl: string,
  supabaseServiceKey: string,
  candidate: RotatingTopicCandidate,
  language: string
): Promise<UnifiedNotificationResult> {
  const localizedContent = await getLocalizedTopicContent(
    supabaseUrl,
    supabaseServiceKey,
    {
      id: candidate.id,
      title: candidate.title,
      description: candidate.description,
      category: candidate.category,
      display_order: 0,
      is_active: true,
    },
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
      topicId: candidate.id,
      topicTitle: localizedContent.title,
      topicDescription: localizedContent.description,
    },
  };
}
