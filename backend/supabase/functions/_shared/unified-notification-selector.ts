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

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { selectTopicsForYouWithLearningPath, getLocalizedTopicContent } from './topic-selector.ts';
import { formatError } from './utils/error-formatter.ts';
import {
  type ActivePathRow,
  type PathTopicRow,
  firstUnfinishedTopic,
  isPathFinished,
  pickContinueLearningTopic,
} from './utils/next-path-topic.ts';

/** Active paths looked at before giving up on "Continue Learning". */
const CONTINUE_PATH_CANDIDATES = 10;

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
 *  2. Active paths -> the first unfinished lesson of the most recently
 *     active one (last_activity_at), at or after its stored cursor.
 *  3. A path whose every visible lesson is done is skipped even when its
 *     stored row still reads completed_at NULL / cursor 0 — a row created
 *     after the lessons were finished (Review, starting a lesson, joining a
 *     fellowship study) is never advanced by the completion trigger. The next
 *     enrolled path with work left is used; none -> null (For You fallback).
 *
 * "Done" means any completion record: user_topic_progress.completed_at or a
 * completed study guide for that topic. Selection lives in the pure helper
 * pickContinueLearningTopic (utils/next-path-topic.ts).
 */
async function selectNextPathTopic(
  supabase: SupabaseClient,
  userId: string
): Promise<NextPathTopic | null> {
  // Several candidates, not just the most recent: the newest row is often a
  // path the user has just finished (or re-opened to review) whose stored
  // completed_at / cursor never caught up.
  const { data: progressRows, error: progressError } = await supabase
    .from('user_learning_path_progress')
    .select('learning_path_id, current_topic_position, learning_paths!inner(is_active)')
    .eq('user_id', userId)
    .is('completed_at', null)
    .eq('learning_paths.is_active', true)
    .order('last_activity_at', { ascending: false })
    .limit(CONTINUE_PATH_CANDIDATES);

  if (progressError) {
    console.error('[UnifiedSelector] Error fetching active learning path progress:', progressError);
    return null;
  }

  const activePaths: ActivePathRow[] = (progressRows || []).map((r: any) => ({
    learning_path_id: r.learning_path_id,
    current_topic_position: r.current_topic_position,
  }));
  if (activePaths.length === 0) {
    return null;
  }

  const [topics, completedTopicIds] = await Promise.all([
    fetchVisiblePathTopics(supabase, activePaths.map((p) => p.learning_path_id)),
    fetchCompletedTopicIds(supabase, userId),
  ]);
  if (!topics || !completedTopicIds) {
    // A failed read must not turn into a push about the wrong lesson.
    return null;
  }

  const next = pickContinueLearningTopic(activePaths, topics, completedTopicIds);
  if (!next) {
    // Every enrolled path is finished (or has nothing visible left).
    return null;
  }

  return {
    topic_id: next.topic_id,
    topic_title: next.title,
    topic_description: next.description,
    topic_category: next.category,
    learning_path_id: next.learning_path_id,
  };
}

/**
 * Visible lessons (active link and active topic) of the given paths, or null
 * on a read error.
 */
async function fetchVisiblePathTopics(
  supabase: SupabaseClient,
  pathIds: string[]
): Promise<PathTopicRow[] | null> {
  if (pathIds.length === 0) return [];
  const { data, error } = await supabase
    .from('learning_path_topics')
    .select('learning_path_id, topic_id, position, recommended_topics!inner(title, description, category, is_active)')
    .in('learning_path_id', pathIds)
    .eq('is_active', true)
    .eq('recommended_topics.is_active', true);

  if (error) {
    console.error('[UnifiedSelector] Error fetching path topics:', error);
    return null;
  }

  return (data || []).map((row: any) => {
    const rt = row.recommended_topics as { title: string; description: string; category: string };
    return {
      learning_path_id: row.learning_path_id,
      topic_id: row.topic_id,
      position: row.position,
      title: rt.title,
      description: rt.description,
      category: rt.category,
    };
  });
}

/**
 * Every topic the user has finished, from both completion records: per-topic
 * progress rows and completed study guides (same sources the in-app For You
 * list uses). Null on a read error.
 */
async function fetchCompletedTopicIds(
  supabase: SupabaseClient,
  userId: string
): Promise<Set<string> | null> {
  const [progress, guides] = await Promise.all([
    supabase
      .from('user_topic_progress')
      .select('topic_id')
      .eq('user_id', userId)
      .not('completed_at', 'is', null),
    supabase
      .from('user_study_guides')
      .select('study_guides!inner(topic_id)')
      .eq('user_id', userId)
      .not('completed_at', 'is', null),
  ]);

  if (progress.error) {
    console.error('[UnifiedSelector] Error fetching completed topics:', progress.error);
    return null;
  }
  if (guides.error) {
    // Secondary source; per-topic rows are authoritative for paths.
    console.error('[UnifiedSelector] Error fetching completed guides:', guides.error);
  }

  const ids = new Set<string>();
  for (const row of progress.data || []) {
    if ((row as any).topic_id) ids.add((row as any).topic_id);
  }
  for (const row of guides.data || []) {
    const topicId = ((row as any).study_guides as { topic_id?: string } | null)?.topic_id;
    if (topicId) ids.add(topicId);
  }
  return ids;
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
 * Walks the ranked candidates (best first), skipping paths the user has
 * finished (stored completion or every visible lesson done) and any path whose
 * first unfinished lesson has already been sent as a for_you/recommended_topic push. Once
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

  const [{ data: completedPaths }, { data: sentLogs }, completedTopicIds] = await Promise.all([
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
    fetchCompletedTopicIds(supabase, userId),
  ]);

  if (!completedTopicIds) {
    return null;
  }

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

  const { data: paths, error: pathsError } = await supabase
    .from('learning_paths')
    .select('id, slug')
    .in('slug', candidateSlugs)
    .eq('is_active', true);
  if (pathsError) {
    console.error('[UnifiedSelector] Error fetching candidate paths:', pathsError);
    return null;
  }
  const pathIdBySlug = new Map<string, string>(
    (paths || []).map((p: { id: string; slug: string }) => [p.slug, p.id])
  );

  const topics = await fetchVisiblePathTopics(supabase, [...pathIdBySlug.values()]);
  if (!topics) {
    return null;
  }

  let firstCandidateTopic: RotatingTopicCandidate | null = null;

  for (const slug of candidateSlugs) {
    const pathId = pathIdBySlug.get(slug);
    if (!pathId) continue;

    // Suggest the first lesson the user has not done — not lesson 1 of a path
    // they already finished through topic rows (stored completed_at may lag).
    const pathTopics = topics.filter((t) => t.learning_path_id === pathId);
    if (isPathFinished(pathTopics, completedTopicIds)) continue;
    const next = firstUnfinishedTopic(pathTopics, completedTopicIds);
    if (!next) continue;

    const candidate: RotatingTopicCandidate = {
      id: next.topic_id,
      title: next.title,
      description: next.description,
      category: next.category,
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
