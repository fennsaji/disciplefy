// ============================================================================
// Topic Selection Service
// ============================================================================
// Intelligent topic selection for personalized recommendations
// Avoids recently sent topics and considers user study history
// Supports questionnaire-based personalization scoring

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
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

interface TopicsForYouResult {
  success: boolean;
  topics?: Topic[];
  error?: string;
  hasCompletedQuestionnaire?: boolean;
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

interface UserPersonalization {
  faith_journey: 'new' | 'growing' | 'mature' | null;
  seeking: Array<'peace' | 'guidance' | 'knowledge' | 'relationships' | 'challenges'>;
  time_commitment: '5min' | '15min' | '30min' | null;
  questionnaire_completed: boolean;
  questionnaire_skipped: boolean;
}

interface ScoredTopic extends Topic {
  score: number;
}

// ============================================================================
// Category Scoring Maps
// ============================================================================

// Maps faith journey stage to preferred categories
const FAITH_JOURNEY_CATEGORIES: Record<string, string[]> = {
  new: ['Foundations of Faith', 'Spiritual Disciplines'],
  growing: ['Christian Life', 'Discipleship & Growth', 'Church & Community'],
  mature: ['Apologetics & Defense of Faith', 'Mission & Service', 'Discipleship & Growth'],
};

// Maps "seeking" values to preferred categories
const SEEKING_CATEGORIES: Record<string, string[]> = {
  peace: ['Spiritual Disciplines', 'Foundations of Faith'],
  guidance: ['Christian Life', 'Discipleship & Growth'],
  knowledge: ['Foundations of Faith', 'Apologetics & Defense of Faith'],
  relationships: ['Family & Relationships', 'Church & Community'],
  challenges: ['Christian Life', 'Apologetics & Defense of Faith', 'Mission & Service'],
};

// Maps faith journey stage to recommended learning path slug
// Priority order: first match wins
const FAITH_JOURNEY_LEARNING_PATHS: Record<string, string[]> = {
  new: ['new-believer-essentials', 'rooted-in-christ'],
  growing: ['growing-in-discipleship', 'deepening-your-walk'],
  mature: ['serving-and-mission', 'defending-your-faith', 'heart-for-the-world'],
};

// Default learning path if no personalization (first in display order)
const DEFAULT_LEARNING_PATH_SLUG = 'new-believer-essentials';

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
      // Fetch all translations for the topics we're considering
      // This handles cases where input_value is in a non-English language
      const topicIds = filteredTopics.map((t: any) => t.id);
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
        for (const trans of translations as any[]) {
          if (topicTitlesMap[trans.topic_id]) {
            topicTitlesMap[trans.topic_id].push(trans.title.toLowerCase().trim());
          }
        }
      }

      // Filter out topics where ANY title (English or translation) matches excluded titles
      filteredTopics = filteredTopics.filter((topic: any) => {
        const allTitles = topicTitlesMap[topic.id] || [topic.title.toLowerCase().trim()];
        // Keep topic only if NONE of its titles are in excludedTitles
        return !allTitles.some((title: string) => allExcludedTitles.includes(title));
      });

      console.log(`After title/input filtering (including translations): ${filteredTopics.length} topics remaining (excluded ${allExcludedTitles.length} titles)`);
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

// ============================================================================
// Personalization Scoring Logic
// ============================================================================

/**
 * Calculates a personalization score for a topic based on user questionnaire answers
 * Higher scores = better match for user
 */
function calculateTopicScore(topic: Topic, personalization: UserPersonalization): number {
  let score = 0;

  // Score based on faith journey (0-30 points)
  if (personalization.faith_journey) {
    const preferredCategories = FAITH_JOURNEY_CATEGORIES[personalization.faith_journey] || [];
    if (preferredCategories.includes(topic.category)) {
      score += 30;
    }
  }

  // Score based on seeking (0-50 points total, 10 per match)
  if (personalization.seeking && personalization.seeking.length > 0) {
    for (const seeking of personalization.seeking) {
      const preferredCategories = SEEKING_CATEGORIES[seeking] || [];
      if (preferredCategories.includes(topic.category)) {
        score += 10;
      }
    }
  }

  // Use display_order as tiebreaker (lower display_order = slightly higher score)
  // Normalize: assume max display_order is ~50, so this adds 0-10 points
  const orderBonus = Math.max(0, 10 - (topic.display_order / 5));
  score += orderBonus;

  return score;
}

/**
 * Scores and sorts topics based on user personalization
 */
function scoreAndSortTopics(topics: Topic[], personalization: UserPersonalization | null): Topic[] {
  if (!personalization || !personalization.questionnaire_completed) {
    // No personalization: sort by display_order only
    return topics.sort((a, b) => a.display_order - b.display_order);
  }

  // Calculate scores and sort
  const scoredTopics: ScoredTopic[] = topics.map((topic) => ({
    ...topic,
    score: calculateTopicScore(topic, personalization),
  }));

  // Sort by score descending, then by display_order ascending
  scoredTopics.sort((a, b) => {
    if (b.score !== a.score) {
      return b.score - a.score;
    }
    return a.display_order - b.display_order;
  });

  // Return topics without the score property
  return scoredTopics.map(({ score, ...topic }) => topic);
}

// ============================================================================
// Topics For You Selection
// ============================================================================

/**
 * Selects personalized topics for a user's "For You" section
 * Returns multiple topics (default 4) ranked by personalization score
 *
 * Logic:
 * 1. Exclude completed topics
 * 2. Exclude topics studied in last 14 days
 * 3. If questionnaire completed: Score by questionnaire answers
 * 4. If questionnaire skipped: Return by display_order
 */
export async function selectTopicsForYou(
  supabaseUrl: string,
  supabaseServiceKey: string,
  userId: string,
  limit: number = 4
): Promise<TopicsForYouResult> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    // Get user's personalization data
    const { data: personalization, error: persError } = await supabase
      .from('user_personalization')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (persError && persError.code !== 'PGRST116') {
      console.error('Error fetching personalization:', persError);
    }

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

    // Score and sort topics based on personalization
    const sortedTopics = scoreAndSortTopics(filteredTopics, personalization);

    // Return top N topics
    return {
      success: true,
      topics: sortedTopics.slice(0, limit),
      hasCompletedQuestionnaire: personalization?.questionnaire_completed || false,
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
 * Selects personalized topics for "For You" section with learning path integration
 * 
 * Priority Logic:
 * 1. If user has an active learning path → show next uncompleted topics from that path
 * 2. If no active path but has personalization → suggest learning path based on faith_journey
 * 3. If no personalization → suggest first learning path (New Believer Essentials)
 * 
 * Returns topics with learning path metadata when applicable
 */
export async function selectTopicsForYouWithLearningPath(
  supabaseUrl: string,
  supabaseServiceKey: string,
  userId: string,
  limit: number = 4
): Promise<TopicsForYouWithPathResult> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  console.log(`[TOPICS_FOR_YOU] Starting selectTopicsForYouWithLearningPath for user: ${userId}, limit: ${limit}`);

  try {
    // Step 1: Check for active learning path (enrolled but not completed)
    console.log('[TOPICS_FOR_YOU] Step 1: Checking for active learning path...');
    const { data: activePathProgress, error: progressError } = await supabase
      .from('user_learning_path_progress')
      .select(`
        learning_path_id,
        current_topic_position,
        topics_completed,
        learning_paths!inner(
          id,
          title,
          slug,
          is_active
        )
      `)
      .eq('user_id', userId)
      .is('completed_at', null)
      .not('enrolled_at', 'is', null)
      .order('last_activity_at', { ascending: false })
      .limit(1);

    if (progressError) {
      console.error('[TOPICS_FOR_YOU] Error fetching active learning path:', progressError);
    }
    console.log(`[TOPICS_FOR_YOU] Active path progress found: ${activePathProgress?.length || 0}`, activePathProgress);

    // Get user's personalization for fallback logic
    const { data: personalization, error: persError } = await supabase
      .from('user_personalization')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (persError && persError.code !== 'PGRST116') {
      console.error('Error fetching personalization:', persError);
    }

    let suggestedPath: { id: string; name: string; reason: 'active' | 'personalized' | 'default' } | undefined;
    let learningPathTopics: LearningPathTopic[] = [];

    // Priority 1: Active learning path
    if (activePathProgress && activePathProgress.length > 0) {
      const activePath = activePathProgress[0];
      const pathData = activePath.learning_paths as any;
      
      if (pathData?.is_active) {
        suggestedPath = {
          id: activePath.learning_path_id,
          name: pathData.title,
          reason: 'active',
        };

        // Get next uncompleted topics from this path
        learningPathTopics = await getNextTopicsFromLearningPath(
          supabase,
          userId,
          activePath.learning_path_id,
          pathData.title,
          limit
        );
      }
    }

    // Priority 2: Personalization-based path suggestion
    if (!suggestedPath && personalization?.questionnaire_completed && personalization?.faith_journey) {
      const recommendedSlugs = FAITH_JOURNEY_LEARNING_PATHS[personalization.faith_journey] || [];
      
      for (const slug of recommendedSlugs) {
        const { data: pathData } = await supabase
          .from('learning_paths')
          .select('id, title, slug')
          .eq('slug', slug)
          .eq('is_active', true)
          .single();

        if (pathData) {
          // Check if user hasn't completed this path
          const { data: existingProgress } = await supabase
            .from('user_learning_path_progress')
            .select('completed_at')
            .eq('user_id', userId)
            .eq('learning_path_id', pathData.id)
            .single();

          // Use this path if not completed
          if (!existingProgress?.completed_at) {
            suggestedPath = {
              id: pathData.id,
              name: pathData.title,
              reason: 'personalized',
            };

            learningPathTopics = await getNextTopicsFromLearningPath(
              supabase,
              userId,
              pathData.id,
              pathData.title,
              limit
            );
            break;
          }
        }
      }
    }

    // Priority 3: Default learning path (first one)
    if (!suggestedPath) {
      const { data: defaultPath } = await supabase
        .from('learning_paths')
        .select('id, title, slug')
        .eq('slug', DEFAULT_LEARNING_PATH_SLUG)
        .eq('is_active', true)
        .single();

      if (defaultPath) {
        // Check if user hasn't completed this path
        const { data: existingProgress } = await supabase
          .from('user_learning_path_progress')
          .select('completed_at')
          .eq('user_id', userId)
          .eq('learning_path_id', defaultPath.id)
          .single();

        if (!existingProgress?.completed_at) {
          suggestedPath = {
            id: defaultPath.id,
            name: defaultPath.title,
            reason: 'default',
          };

          learningPathTopics = await getNextTopicsFromLearningPath(
            supabase,
            userId,
            defaultPath.id,
            defaultPath.title,
            limit
          );
        }
      }
    }

    // If we have learning path topics, return them
    console.log(`[TOPICS_FOR_YOU] Learning path topics found: ${learningPathTopics.length}`);
    if (learningPathTopics.length > 0) {
      console.log('[TOPICS_FOR_YOU] Returning learning path topics:');
      for (const topic of learningPathTopics) {
        console.log(`  - ${topic.title} (path: ${topic.learning_path_name}, position: ${topic.position_in_path}/${topic.total_topics_in_path})`);
      }
      return {
        success: true,
        topics: learningPathTopics,
        hasCompletedQuestionnaire: personalization?.questionnaire_completed || false,
        suggestedLearningPath: suggestedPath,
      };
    }
    console.log('[TOPICS_FOR_YOU] No learning path topics, falling back to regular selectTopicsForYou');

    // Fallback: Use the regular selectTopicsForYou logic
    const fallbackResult = await selectTopicsForYou(
      supabaseUrl,
      supabaseServiceKey,
      userId,
      limit
    );

    return {
      success: fallbackResult.success,
      topics: fallbackResult.topics,
      error: fallbackResult.error,
      hasCompletedQuestionnaire: fallbackResult.hasCompletedQuestionnaire,
      suggestedLearningPath: suggestedPath,
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
    .eq('learning_path_id', learningPathId);

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
