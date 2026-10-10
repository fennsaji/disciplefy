// ============================================================================
// Topic Selection Service
// ============================================================================
// Lessons to suggest: the next unfinished lessons of the path the next-path
// engine picks (_shared/personalization/next-paths.ts), and, when no path has
// lessons left, catalogue topics the user has not studied.
//
// The questionnaire-based topic scoring (category maps, faith stage, legacy
// faith_journey answers) was removed on 2026-10-10 with the questionnaire.

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getServiceRoleClient } from './core/service-client.ts';
import { formatError } from './utils/error-formatter.ts';
import { legacyTopicReason, loadNextPaths } from './personalization/next-paths.ts';

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

interface TopicsForYouResult {
  success: boolean;
  topics?: Topic[];
  error?: string;
}

interface LearningPathTopic extends Topic {
  learning_path_id: string;
  learning_path_name: string;
  position_in_path: number;
  total_topics_in_path: number;
}

interface TopicsForYouWithPathResult {
  success: boolean;
  topics?: (Topic | LearningPathTopic)[];
  error?: string;
  /**
   * True when the user has a growth goal or finished the retired
   * questionnaire. Older apps show their questionnaire prompt when false.
   */
  hasCompletedQuestionnaire?: boolean;
  suggestedLearningPath?: {
    id: string;
    name: string;
    reason: 'active' | 'personalized' | 'default';
  };
}

interface LocalizedContent {
  title: string;
  description: string;
}

/** Engine picks tried for lessons before falling back to catalogue topics. */
const PATH_CANDIDATES = 5;

// ============================================================================
// Localization Helper
// ============================================================================

/**
 * Localizes many topics with one query instead of one per topic.
 *
 * Mirrors getLocalizedTopicContent per topic: a translation row, when present,
 * is used as-is; no row or a failed query falls back to the English content.
 * Result order matches `topics`.
 */
export async function getLocalizedTopicsContent(
  supabase: SupabaseClient,
  topics: Topic[],
  language: string
): Promise<LocalizedContent[]> {
  const english = topics.map((t) => ({ title: t.title, description: t.description }))
  if (language === 'en' || topics.length === 0) return english

  try {
    const ids = [...new Set(topics.map((t) => t.id))]
    const { data, error } = await supabase
      .from('recommended_topics_translations')
      .select('topic_id, title, description')
      .in('topic_id', ids)
      .eq('language_code', language)

    if (error) {
      console.error(`Translation batch fetch error for language ${language}:`, error)
      return english
    }

    return mergeTopicTranslations(topics, data ?? [])
  } catch (error) {
    console.error('Error fetching topic translations:', error)
    return english
  }
}

/** Pure merge step of getLocalizedTopicsContent, exported for tests. */
export function mergeTopicTranslations(
  topics: Topic[],
  rows: { topic_id: string; title: string; description: string }[]
): LocalizedContent[] {
  const byId = new Map<string, { title: string; description: string }>()
  const duplicated = new Set<string>()
  for (const row of rows) {
    if (byId.has(row.topic_id)) duplicated.add(row.topic_id)
    else byId.set(row.topic_id, { title: row.title, description: row.description })
  }
  return topics.map((t) => {
    const row = byId.get(t.id)
    // .single() errored on duplicates and fell back to English; keep that.
    if (!row || duplicated.has(t.id)) return { title: t.title, description: t.description }
    return { title: row.title, description: row.description }
  })
}

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
  const supabase = getServiceRoleClient(supabaseUrl, supabaseServiceKey);
  
  try {
    const { data: translation, error } = await supabase
      .from('recommended_topics_translations')
      .select('title, description')
      .eq('topic_id', topic.id)
      .eq('language_code', language)
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

// ============================================================================
// Topics For You Selection
// ============================================================================

/**
 * Catalogue topics for a user, used when no path has lessons left:
 * completed topics and topics studied in the last 14 days are left out, the
 * rest come in display order.
 */
export async function selectTopicsForYou(
  supabaseUrl: string,
  supabaseServiceKey: string,
  userId: string,
  limit: number = 4,
  client?: SupabaseClient
): Promise<TopicsForYouResult> {
  // Reuse the caller's service client when given; a new client per call
  // costs a fresh connection setup.
  const supabase = client ?? getServiceRoleClient(supabaseUrl, supabaseServiceKey);

  try {
    // Get completed topics to exclude
    const { data: completedGuides, error: completedError } = await supabase
      .from('user_study_guides')
      .select('study_guide_id, study_guides!inner(topic_id, input_type, input_value)')
      .eq('user_id', userId)
      .not('completed_at', 'is', null);

    if (completedError) {
      console.error('Error fetching completed guides:', completedError);
    }

    let excludedTopicIds: string[] = [];
    let excludedTitles: string[] = [];

    if (completedGuides && completedGuides.length > 0) {
      for (const guide of completedGuides) {
        const studyGuide = guide.study_guides as any;
        if (studyGuide?.topic_id) {
          excludedTopicIds.push(studyGuide.topic_id);
        } else if (studyGuide?.input_type === 'topic' && studyGuide?.input_value) {
          excludedTitles.push(studyGuide.input_value.toLowerCase().trim());
        }
      }
      excludedTopicIds = [...new Set(excludedTopicIds)];
      excludedTitles = [...new Set(excludedTitles)];
    }

    // Get recently studied incomplete topics (14 days) to exclude
    const fourteenDaysAgo = new Date();
    fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);

    const { data: recentGuides, error: recentError } = await supabase
      .from('user_study_guides')
      .select('study_guide_id, study_guides!inner(topic_id, input_type, input_value, created_at)')
      .eq('user_id', userId)
      .is('completed_at', null)
      .gte('study_guides.created_at', fourteenDaysAgo.toISOString());

    if (recentError) {
      console.error('Error fetching recent guides:', recentError);
    }

    if (recentGuides && recentGuides.length > 0) {
      for (const guide of recentGuides) {
        const studyGuide = guide.study_guides as any;
        if (studyGuide?.topic_id) {
          excludedTopicIds.push(studyGuide.topic_id);
        } else if (studyGuide?.input_type === 'topic' && studyGuide?.input_value) {
          excludedTitles.push(studyGuide.input_value.toLowerCase().trim());
        }
      }
      excludedTopicIds = [...new Set(excludedTopicIds)];
      excludedTitles = [...new Set(excludedTitles)];
    }

    // Fetch all active topics
    let query = supabase.from('recommended_topics').select('*').eq('is_active', true);

    if (excludedTopicIds.length > 0) {
      query = query.not('id', 'in', `(${excludedTopicIds.join(',')})`);
    }

    const { data: topics, error: topicsError } = await query;

    if (topicsError) {
      return {
        success: false,
        error: `Failed to fetch topics: ${topicsError.message}`,
      };
    }

    // Filter by title for pre-migration guides
    // Need to also check translations since input_value may be in non-English language
    let filteredTopics = topics || [];
    if (excludedTitles.length > 0 && filteredTopics.length > 0) {
      // Fetch all translations for the topics we're considering
      const topicIds = filteredTopics.map((t) => t.id);
      const { data: translations, error: transError } = await supabase
        .from('recommended_topics_translations')
        .select('topic_id, title')
        .in('topic_id', topicIds);

      if (transError) {
        console.error('Error fetching translations for filtering:', transError);
      }

      // Build a map of topic_id -> all titles (English + translations)
      const topicTitlesMap: Record<string, string[]> = {};
      for (const topic of filteredTopics) {
        topicTitlesMap[topic.id] = [topic.title.toLowerCase().trim()];
      }
      if (translations) {
        for (const trans of translations) {
          if (topicTitlesMap[trans.topic_id]) {
            topicTitlesMap[trans.topic_id].push(trans.title.toLowerCase().trim());
          }
        }
      }

      // Filter out topics where ANY title (English or translation) matches excluded titles
      filteredTopics = filteredTopics.filter((topic) => {
        const allTitles = topicTitlesMap[topic.id] || [topic.title.toLowerCase().trim()];
        // Keep topic only if NONE of its titles are in excludedTitles
        return !allTitles.some((title) => excludedTitles.includes(title));
      });

      console.log(`After title filtering (including translations): ${filteredTopics.length} topics remaining`);
    }

    const sortedTopics = [...filteredTopics].sort((x, y) => x.display_order - y.display_order);

    // Return top N topics
    return {
      success: true,
      topics: sortedTopics.slice(0, limit),
    };
  } catch (error) {
    return {
      success: false,
      error: formatError(error, 'Topics for you selection error'),
    };
  }
}

// ============================================================================
// Topics For You with Learning Path Integration
// ============================================================================

/**
 * The next lessons to suggest, with the path they belong to.
 *
 * Paths come from the next-path engine (active path, goal list, featured,
 * catalogue); the first one with an unfinished lesson wins. When none has,
 * catalogue topics are returned instead (no suggested path).
 */
export async function selectTopicsForYouWithLearningPath(
  supabaseUrl: string,
  supabaseServiceKey: string,
  userId: string,
  limit: number = 4,
  client?: SupabaseClient,
  isGuest = false
): Promise<TopicsForYouWithPathResult> {
  // Reuse the caller's service client when given; a new client per call
  // costs a fresh connection setup.
  const supabase = client ?? getServiceRoleClient(supabaseUrl, supabaseServiceKey);

  try {
    const [next, { data: personalization }] = await Promise.all([
      loadNextPaths(supabase, { userId, isGuest, limit: PATH_CANDIDATES }),
      supabase
        .from('user_personalization')
        .select('questionnaire_completed')
        .eq('user_id', userId)
        .maybeSingle(),
    ]);
    const hasCompletedQuestionnaire =
      next.goal !== null || personalization?.questionnaire_completed === true;

    if (next.paths.length > 0) {
      const ids = next.paths.map((p) => p.pathId);
      const { data: rows } = await supabase
        .from('learning_paths')
        .select('id, title')
        .in('id', ids);
      const titleById = new Map<string, string>(
        (rows ?? []).map((r: { id: string; title: string }) => [r.id, r.title])
      );

      for (const pick of next.paths) {
        const title = titleById.get(pick.pathId);
        if (title === undefined) continue;
        const topics = await getNextTopicsFromLearningPath(supabase, userId, pick.pathId, title, limit);
        if (topics.length === 0) continue;
        return {
          success: true,
          topics,
          hasCompletedQuestionnaire,
          suggestedLearningPath: { id: pick.pathId, name: title, reason: legacyTopicReason(pick.reason) },
        };
      }
    }

    // No path with lessons left: catalogue topics.
    const fallback = await selectTopicsForYou(supabaseUrl, supabaseServiceKey, userId, limit, supabase);
    return {
      success: fallback.success,
      topics: fallback.topics,
      error: fallback.error,
      hasCompletedQuestionnaire,
    };
  } catch (error) {
    return {
      success: false,
      error: formatError(error, 'Topics for you with learning path error'),
    };
  }
}

/**
 * Helper function to get next uncompleted topics from a learning path
 */
async function getNextTopicsFromLearningPath(
  supabase: SupabaseClient,
  userId: string,
  learningPathId: string,
  learningPathName: string,
  limit: number
): Promise<LearningPathTopic[]> {
  console.log(`[TOPICS_FOR_YOU] getNextTopicsFromLearningPath called:`);
  console.log(`  - learningPathId: ${learningPathId}`);
  console.log(`  - learningPathName: ${learningPathName}`);
  console.log(`  - limit: ${limit}`);

  // Get total topics count in the path
  const { data: totalCount, error: countError } = await supabase
    .from('learning_path_topics')
    .select('id', { count: 'exact' })
    .eq('learning_path_id', learningPathId)
    .eq('is_active', true);

  if (countError) {
    console.error('[TOPICS_FOR_YOU] Error counting topics:', countError);
  }

  const totalTopicsInPath = totalCount?.length || 0;
  console.log(`[TOPICS_FOR_YOU] Total topics in path: ${totalTopicsInPath}`);

  // Get all topics in the learning path with their positions
  const { data: pathTopics, error: pathError } = await supabase
    .from('learning_path_topics')
    .select(`
      topic_id,
      position,
      recommended_topics!inner(
        id,
        title,
        description,
        category,
        display_order,
        is_active,
        xp_value
      )
    `)
    .eq('learning_path_id', learningPathId)
    .eq('is_active', true)
    .order('position', { ascending: true });

  if (pathError || !pathTopics) {
    console.error('[TOPICS_FOR_YOU] Error fetching learning path topics:', pathError);
    return [];
  }
  console.log(`[TOPICS_FOR_YOU] Path topics fetched: ${pathTopics.length}`);

  // Get user's completed topic IDs from BOTH user_topic_progress AND user_study_guides
  // This ensures consistency with selectTopicForUser and selectTopicsForYou functions
  
  // Check user_topic_progress table
  const { data: completedFromProgress } = await supabase
    .from('user_topic_progress')
    .select('topic_id')
    .eq('user_id', userId)
    .not('completed_at', 'is', null);

  // Check user_study_guides table (primary source of completion tracking)
  const { data: completedGuides } = await supabase
    .from('user_study_guides')
    .select('study_guide_id, study_guides!inner(topic_id, input_type, input_value)')
    .eq('user_id', userId)
    .not('completed_at', 'is', null);

  // Combine topic IDs from both sources
  const completedTopicIds = new Set<string>(
    completedFromProgress?.map((t) => t.topic_id) || []
  );

  // Add topic IDs from completed study guides
  if (completedGuides && completedGuides.length > 0) {
    for (const guide of completedGuides) {
      const studyGuide = guide.study_guides as any;
      if (studyGuide?.topic_id) {
        completedTopicIds.add(studyGuide.topic_id);
      }
    }
  }

  console.log(`[TOPICS_FOR_YOU] Found ${completedTopicIds.size} completed topics (${completedFromProgress?.length || 0} from progress, ${completedGuides?.length || 0} from study guides)`);

  // Filter to only uncompleted topics and map to LearningPathTopic format
  const uncompletedTopics: LearningPathTopic[] = [];

  for (const pt of pathTopics) {
    const topic = pt.recommended_topics as any;
    
    if (!topic?.is_active) continue;
    if (completedTopicIds.has(pt.topic_id)) continue;

    uncompletedTopics.push({
      id: topic.id,
      title: topic.title,
      description: topic.description,
      category: topic.category,
      display_order: topic.display_order,
      is_active: topic.is_active,
      learning_path_id: learningPathId,
      learning_path_name: learningPathName,
      position_in_path: pt.position,
      total_topics_in_path: totalTopicsInPath,
    });

    if (uncompletedTopics.length >= limit) break;
  }

  console.log(`[TOPICS_FOR_YOU] Returning ${uncompletedTopics.length} uncompleted topics from learning path`);
  return uncompletedTopics;
}
