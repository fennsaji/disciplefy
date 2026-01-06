/**
 * Learning Paths Edge Function
 *
 * Handles all learning path operations:
 * - GET: List available learning paths
 * - GET /{id}: Get learning path details with topics
 * - POST /enroll: Enroll in a learning path
 *
 * Part of Phase 3: Study Topics Page Revamp
 */

import { createFunction } from '../_shared/core/function-factory.ts';
import { ServiceContainer } from '../_shared/core/services.ts';
import { UserContext } from '../_shared/types/index.ts';
import { AppError } from '../_shared/utils/error-handler.ts';
import {
  calculatePathScores,
  type QuestionnaireResponses,
  type LearningPath as ScoringLearningPath,
} from '../_shared/personalization/scoring-algorithm.ts';

// ============================================================================
// Types
// ============================================================================

interface LearningPathsRequest {
  language?: string;
  includeEnrolled?: boolean;
}

interface LearningPathDetailRequest {
  pathId: string;
  language?: string;
}

interface EnrollRequest {
  pathId: string;
}

interface LearningPath {
  id: string;
  slug: string;
  title: string;
  description: string;
  icon_name: string;
  color: string;
  total_xp: number;
  estimated_days: number;
  disciple_level: string;
  recommended_mode?: string;
  is_featured: boolean;
  topics_count: number;
  is_enrolled: boolean;
  progress_percentage: number;
}

interface LearningPathDetail extends LearningPath {
  allow_non_sequential_access: boolean;
  topics_completed: number;
  enrolled_at: string | null;
  topics: LearningPathTopic[];
}

interface LearningPathTopic {
  position: number;
  is_milestone: boolean;
  topic_id: string;
  title: string;
  description: string;
  category: string;
  input_type: string;
  xp_value: number;
  is_completed: boolean;
  is_in_progress: boolean;
}

interface EnrollmentResult {
  id: string;
  learning_path_id: string;
  enrolled_at: string;
  started_at: string;
}

interface RecommendedPathResult {
  path: LearningPath | null;
  reason: 'active' | 'personalized' | 'featured';
}

interface RecommendedPathRequest {
  language?: string;
}

/**
 * Shape of learning_paths row from joined query
 */
interface LearningPathRow {
  id: string;
  slug: string;
  title: string;
  description: string;
  icon_name: string;
  color: string;
  total_xp: number;
  estimated_days: number;
  disciple_level: string;
  is_featured: boolean;
  is_active: boolean;
  recommended_mode?: string;
  display_order?: number;
}

// Default learning path slug for anonymous users or users without personalization
const DEFAULT_FEATURED_PATH_SLUG = 'new-believer-essentials';

// ============================================================================
// Helper Functions for Learning Path Recommendations
// ============================================================================

/**
 * Gets the count of topics in a learning path
 */
async function getTopicsCount(
  supabaseClient: ReturnType<ServiceContainer['supabaseServiceClient']['from']> extends (...args: any[]) => any ? any : any,
  learningPathId: string
): Promise<number> {
  const { data } = await supabaseClient
    .from('learning_path_topics')
    .select('id', { count: 'exact' })
    .eq('learning_path_id', learningPathId);
  return data?.length || 0;
}

/**
 * Gets localized title and description for a learning path
 */
async function getLocalizedTitleDescription(
  supabaseClient: ReturnType<ServiceContainer['supabaseServiceClient']['from']> extends (...args: any[]) => any ? any : any,
  learningPathId: string,
  language: string,
  fallbackTitle: string,
  fallbackDescription: string
): Promise<{ title: string; description: string }> {
  if (language === 'en') {
    return { title: fallbackTitle, description: fallbackDescription };
  }

  const { data: translation } = await supabaseClient
    .from('learning_path_translations')
    .select('title, description')
    .eq('learning_path_id', learningPathId)
    .eq('lang_code', language)
    .single();

  if (translation) {
    return {
      title: translation.title || fallbackTitle,
      description: translation.description || fallbackDescription,
    };
  }

  return { title: fallbackTitle, description: fallbackDescription };
}

/**
 * Builds a LearningPath response object from path data
 */
function buildLearningPathResponse(
  pathData: Record<string, any>,
  topicsCount: number,
  isEnrolled: boolean,
  progressPercentage: number,
  localizedTitle: string,
  localizedDescription: string
): LearningPath {
  return {
    id: pathData.id,
    slug: pathData.slug,
    title: localizedTitle,
    description: localizedDescription,
    icon_name: pathData.icon_name,
    color: pathData.color,
    total_xp: pathData.total_xp,
    estimated_days: pathData.estimated_days,
    disciple_level: pathData.disciple_level,
    is_featured: pathData.is_featured,
    topics_count: topicsCount,
    is_enrolled: isEnrolled,
    progress_percentage: progressPercentage,
  };
}

/**
 * Creates a JSON response for the recommended path
 */
function createRecommendedPathResponse(
  path: LearningPath | null,
  reason: 'active' | 'personalized' | 'featured'
): Response {
  return new Response(
    JSON.stringify({
      success: true,
      data: { path, reason },
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleLearningPaths(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  const url = new URL(req.url);
  const pathSegments = url.pathname.split('/').filter(Boolean);

  // Determine the action based on URL pattern and method
  // /learning-paths -> list paths
  // /learning-paths?pathId=xxx -> get path details (via query param)
  // /learning-paths/enroll -> enroll in path
  // /learning-paths?action=recommended -> get recommended path for user

  const method = req.method.toUpperCase();
  const action = url.searchParams.get('action');

  // Check if this is a recommended path request
  const isRecommendedRequest = pathSegments.includes('recommended') ||
    action === 'recommended';

  if ((method === 'GET' || method === 'POST') && isRecommendedRequest) {
    return handleGetRecommendedPath(req, services, userContext);
  }

  // Check if this is an enroll request
  const isEnrollRequest = pathSegments.includes('enroll') ||
    (method === 'POST' && action === 'enroll');

  if (method === 'POST' && isEnrollRequest) {
    return handleEnroll(req, services, userContext);
  }

  if (method === 'GET' || method === 'POST') {
    // Check if requesting specific path details via query param
    const pathIdFromQuery = url.searchParams.get('pathId');
    if (pathIdFromQuery) {
      return handleGetPathDetails(req, services, userContext, pathIdFromQuery);
    }

    // For POST, also check the body for pathId (frontend sends it in body)
    if (method === 'POST') {
      try {
        const clonedReq = req.clone();
        const body = await clonedReq.json();
        if (body.pathId) {
          return handleGetPathDetails(req, services, userContext, body.pathId, body.language);
        }
      } catch {
        // If body parsing fails, continue to list paths
      }
    }

    // Otherwise list all paths
    return handleListPaths(req, services, userContext);
  }

  throw new AppError('INVALID_REQUEST', 'Method not allowed', 405);
}

// ============================================================================
// List Learning Paths
// ============================================================================

async function handleListPaths(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  const { supabaseServiceClient } = services;

  // Parse request body or query params
  let language = 'en';
  let includeEnrolled = true;

  if (req.method === 'POST') {
    try {
      const body: LearningPathsRequest = await req.json();
      language = body.language || 'en';
      includeEnrolled = body.includeEnrolled ?? true;
    } catch {
      // Use defaults if body parsing fails
    }
  } else {
    const url = new URL(req.url);
    language = url.searchParams.get('language') || 'en';
    includeEnrolled = url.searchParams.get('includeEnrolled') !== 'false';
  }

  const userId = userContext?.type === 'authenticated' ? userContext.userId : null;

  // Call the database function
  const { data, error } = await supabaseServiceClient.rpc('get_available_learning_paths', {
    p_user_id: userId,
    p_language: language,
    p_include_enrolled: includeEnrolled,
  });

  if (error) {
    console.error('Error fetching learning paths:', error);
    throw new AppError('DATABASE_ERROR', 'Failed to fetch learning paths', 500);
  }

  const paths: LearningPath[] = (data || []).map((row: Record<string, unknown>) => ({
    id: row.path_id as string,
    slug: row.slug as string,
    title: row.title as string,
    description: row.description as string,
    icon_name: row.icon_name as string,
    color: row.color as string,
    total_xp: row.total_xp as number,
    estimated_days: row.estimated_days as number,
    disciple_level: row.disciple_level as string,
    is_featured: row.is_featured as boolean,
    topics_count: row.topics_count as number,
    is_enrolled: row.is_enrolled as boolean,
    progress_percentage: row.progress_percentage as number,
  }));

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        paths,
        total: paths.length,
      },
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}

// ============================================================================
// Get Learning Path Details
// ============================================================================

async function handleGetPathDetails(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext,
  pathId?: string,
  languageFromBody?: string
): Promise<Response> {
  const { supabaseServiceClient } = services;

  // Parse request
  let language = languageFromBody || 'en';
  let resolvedPathId = pathId;

  // If language wasn't passed from body parsing, try to get it from query
  if (!languageFromBody) {
    const url = new URL(req.url);
    language = url.searchParams.get('language') || 'en';
  }

  if (!resolvedPathId) {
    throw new AppError('VALIDATION_ERROR', 'pathId is required', 400);
  }

  const userId = userContext?.type === 'authenticated' ? userContext.userId : null;

  // Call the database function
  const { data, error } = await supabaseServiceClient.rpc('get_learning_path_details', {
    p_path_id: resolvedPathId,
    p_user_id: userId,
    p_language: language,
  });

  if (error) {
    console.error('Error fetching learning path details:', error);
    throw new AppError('DATABASE_ERROR', 'Failed to fetch learning path details', 500);
  }

  if (!data || data.length === 0) {
    throw new AppError('NOT_FOUND', 'Learning path not found', 404);
  }

  const row = data[0];
  const pathDetail: LearningPathDetail = {
    id: row.path_id,
    slug: row.slug,
    title: row.title,
    description: row.description,
    icon_name: row.icon_name,
    color: row.color,
    total_xp: row.total_xp,
    estimated_days: row.estimated_days,
    disciple_level: row.disciple_level,
    recommended_mode: row.recommended_mode,
    allow_non_sequential_access: row.allow_non_sequential_access,
    is_featured: false,
    topics_count: row.topics?.length || 0,
    is_enrolled: row.is_enrolled,
    progress_percentage: row.progress_percentage,
    topics_completed: row.topics_completed,
    enrolled_at: row.enrolled_at,
    topics: (row.topics || []).map((topic: Record<string, unknown>) => ({
      position: topic.position as number,
      is_milestone: topic.is_milestone as boolean,
      topic_id: topic.topic_id as string,
      title: topic.title as string,
      description: topic.description as string,
      category: topic.category as string,
      input_type: topic.input_type as string,
      xp_value: topic.xp_value as number,
      is_completed: topic.is_completed as boolean,
      is_in_progress: topic.is_in_progress as boolean,
    })),
  };

  return new Response(
    JSON.stringify({
      success: true,
      data: pathDetail,
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}

// ============================================================================
// Enroll in Learning Path
// ============================================================================

async function handleEnroll(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  // Require authentication for enrollment
  if (!userContext || userContext.type !== 'authenticated') {
    throw new AppError('UNAUTHORIZED', 'Authentication required to enroll', 401);
  }

  const { supabaseServiceClient } = services;

  // Parse request
  let pathId: string | null = null;

  try {
    const body: EnrollRequest = await req.json();
    pathId = body.pathId;
  } catch {
    const url = new URL(req.url);
    pathId = url.searchParams.get('pathId');
  }

  if (!pathId) {
    throw new AppError('VALIDATION_ERROR', 'pathId is required', 400);
  }

  // Call the database function
  const { data, error } = await supabaseServiceClient.rpc('enroll_in_learning_path', {
    p_user_id: userContext.userId,
    p_learning_path_id: pathId,
  });

  if (error) {
    console.error('Error enrolling in learning path:', error);

    if (error.message?.includes('not found') || error.message?.includes('inactive')) {
      throw new AppError('NOT_FOUND', 'Learning path not found or inactive', 404);
    }

    throw new AppError('DATABASE_ERROR', 'Failed to enroll in learning path', 500);
  }

  const result: EnrollmentResult = {
    id: data.id,
    learning_path_id: data.learning_path_id,
    enrolled_at: data.enrolled_at,
    started_at: data.started_at,
  };

  return new Response(
    JSON.stringify({
      success: true,
      data: result,
      message: 'Successfully enrolled in learning path',
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}

// ============================================================================
// Get Recommended Learning Path
// ============================================================================

/**
 * Returns a single recommended learning path based on priority:
 * 1. Active learning path (enrolled and in-progress) for authenticated users
 * 2. Personalized path based on questionnaire responses for authenticated users
 * 3. Featured learning path for anonymous users or users without personalization
 */
async function handleGetRecommendedPath(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  const { supabaseServiceClient } = services;

  // Parse language from request
  let language = 'en';
  if (req.method === 'POST') {
    try {
      const body: RecommendedPathRequest = await req.json();
      language = body.language || 'en';
    } catch {
      // Use default
    }
  } else {
    const url = new URL(req.url);
    language = url.searchParams.get('language') || 'en';
  }

  const userId = userContext?.type === 'authenticated' ? userContext.userId : null;

  console.log(`[RECOMMENDED_PATH] Getting recommended path for user: ${userId || 'anonymous'}, language: ${language}`);

  try {
    // Priority 1: Check for active learning path (authenticated users only)
    if (userId) {
      console.log('[RECOMMENDED_PATH] Checking for active learning path...');
      const { data: activePathProgress, error: progressError } = await supabaseServiceClient
        .from('user_learning_path_progress')
        .select(`
          learning_path_id,
          current_topic_position,
          topics_completed,
          learning_paths!inner(
            id,
            slug,
            title,
            description,
            icon_name,
            color,
            total_xp,
            estimated_days,
            disciple_level,
            is_featured,
            is_active
          )
        `)
        .eq('user_id', userId)
        .is('completed_at', null)
        .not('started_at', 'is', null)
        .order('last_activity_at', { ascending: false })
        .limit(1);

      if (progressError) {
        console.error('[RECOMMENDED_PATH] Error fetching active path:', progressError);
      }

      if (activePathProgress && activePathProgress.length > 0) {
        const activePath = activePathProgress[0];
        // Supabase returns joined relation as object (due to !inner), cast through unknown for type safety
        const pathData = activePath.learning_paths as unknown as LearningPathRow | null;

        if (pathData?.is_active) {
          console.log(`[RECOMMENDED_PATH] Found active path: ${pathData.title}`);

          const topicsCountNum = await getTopicsCount(supabaseServiceClient, activePath.learning_path_id);
          const localized = await getLocalizedTitleDescription(
            supabaseServiceClient,
            activePath.learning_path_id,
            language,
            pathData.title,
            pathData.description
          );
          const progressPercentage = topicsCountNum > 0
            ? Math.round((activePath.topics_completed / topicsCountNum) * 100)
            : 0;

          const path = buildLearningPathResponse(
            pathData,
            topicsCountNum,
            true,
            progressPercentage,
            localized.title,
            localized.description
          );

          return createRecommendedPathResponse(path, 'active');
        }
      }
    }

    // Priority 2: Get personalized path based on questionnaire (authenticated users only)
    if (userId) {
      console.log('[RECOMMENDED_PATH] Checking for personalization...');
      const { data: personalization, error: persError } = await supabaseServiceClient
        .from('user_personalization')
        .select('faith_stage, spiritual_goals, time_availability, learning_style, life_stage_focus, biggest_challenge, questionnaire_completed')
        .eq('user_id', userId)
        .single();

      if (persError && persError.code !== 'PGRST116') {
        console.error('[RECOMMENDED_PATH] Error fetching personalization:', persError);
      }

      if (personalization?.questionnaire_completed && personalization?.faith_stage) {
        console.log(`[RECOMMENDED_PATH] User has personalization, faith_stage: ${personalization.faith_stage}`);

        // Fetch all active learning paths for scoring
        const { data: allPaths, error: pathsError } = await supabaseServiceClient
          .from('learning_paths')
          .select('id, slug, title, description, icon_name, color, total_xp, estimated_days, disciple_level, recommended_mode, is_featured, display_order')
          .eq('is_active', true);

        if (pathsError || !allPaths || allPaths.length === 0) {
          console.error('[RECOMMENDED_PATH] Error fetching paths for scoring:', pathsError);
        } else {
          // Fetch user's completed paths
          const { data: completedPaths, error: completedError } = await supabaseServiceClient
            .from('user_learning_path_progress')
            .select('learning_path_id')
            .eq('user_id', userId)
            .eq('completed_at', 'not.is.null');

          if (completedError && completedError.code !== 'PGRST116') {
            console.error('[RECOMMENDED_PATH] Error fetching completed paths:', completedError);
          }

          const completedPathIds = (completedPaths || []).map((p) => p.learning_path_id);

          // Build questionnaire responses object for scoring
          const responses: QuestionnaireResponses = {
            faith_stage: personalization.faith_stage as QuestionnaireResponses['faith_stage'],
            spiritual_goals: personalization.spiritual_goals || [],
            time_availability: personalization.time_availability as QuestionnaireResponses['time_availability'],
            learning_style: personalization.learning_style as QuestionnaireResponses['learning_style'],
            life_stage_focus: personalization.life_stage_focus as QuestionnaireResponses['life_stage_focus'],
            biggest_challenge: personalization.biggest_challenge as QuestionnaireResponses['biggest_challenge'],
          };

          // Calculate scores using scoring algorithm
          const scoredPaths = calculatePathScores(
            responses,
            allPaths as ScoringLearningPath[],
            completedPathIds
          );

          // Get top recommendation (first in sorted list)
          if (scoredPaths.length > 0) {
            const topPath = scoredPaths[0];
            console.log(`[RECOMMENDED_PATH] Found personalized path via scoring: ${topPath.pathTitle} (score: ${topPath.score})`);

            // Fetch full path data for response
            const { data: pathData, error: pathError } = await supabaseServiceClient
              .from('learning_paths')
              .select('*')
              .eq('id', topPath.pathId)
              .single();

            if (pathError || !pathData) {
              console.error('[RECOMMENDED_PATH] Error fetching recommended path data:', pathError);
            } else {
              const topicsCountNum = await getTopicsCount(supabaseServiceClient, pathData.id);
              const localized = await getLocalizedTitleDescription(
                supabaseServiceClient,
                pathData.id,
                language,
                pathData.title,
                pathData.description
              );

              // Check if user is enrolled
              const { data: existingProgress } = await supabaseServiceClient
                .from('user_learning_path_progress')
                .select('topics_completed')
                .eq('user_id', userId)
                .eq('learning_path_id', pathData.id)
                .single();

              const progressPercentage = existingProgress && topicsCountNum > 0
                ? Math.round((existingProgress.topics_completed / topicsCountNum) * 100)
                : 0;

              const path = buildLearningPathResponse(
                pathData,
                topicsCountNum,
                !!existingProgress,
                progressPercentage,
                localized.title,
                localized.description
              );

              return createRecommendedPathResponse(path, 'personalized');
            }
          }
        }
      }
    }

    // Priority 3: Return featured learning path (for anonymous or non-personalized users)
    console.log('[RECOMMENDED_PATH] Falling back to featured path...');
    const { data: featuredPath, error: featuredError } = await supabaseServiceClient
      .from('learning_paths')
      .select('*')
      .eq('slug', DEFAULT_FEATURED_PATH_SLUG)
      .eq('is_active', true)
      .single();

    if (featuredError || !featuredPath) {
      // Fallback to any featured path
      const { data: anyFeatured } = await supabaseServiceClient
        .from('learning_paths')
        .select('*')
        .eq('is_featured', true)
        .eq('is_active', true)
        .order('display_order', { ascending: true })
        .limit(1)
        .single();

      if (!anyFeatured) {
        console.log('[RECOMMENDED_PATH] No featured path found');
        return createRecommendedPathResponse(null, 'featured');
      }

      // Use anyFeatured
      const pathData = anyFeatured;
      const topicsCountNum = await getTopicsCount(supabaseServiceClient, pathData.id);
      const localized = await getLocalizedTitleDescription(
        supabaseServiceClient,
        pathData.id,
        language,
        pathData.title,
        pathData.description
      );

      const path = buildLearningPathResponse(
        pathData,
        topicsCountNum,
        false,
        0,
        localized.title,
        localized.description
      );

      return createRecommendedPathResponse(path, 'featured');
    }

    // Use the default featured path
    console.log(`[RECOMMENDED_PATH] Using default featured path: ${featuredPath.title}`);

    const topicsCountNum = await getTopicsCount(supabaseServiceClient, featuredPath.id);
    const localized = await getLocalizedTitleDescription(
      supabaseServiceClient,
      featuredPath.id,
      language,
      featuredPath.title,
      featuredPath.description
    );

    // Check if user is enrolled (authenticated users only)
    let isEnrolled = false;
    let progressPercentage = 0;

    if (userId) {
      const { data: userProgress } = await supabaseServiceClient
        .from('user_learning_path_progress')
        .select('topics_completed')
        .eq('user_id', userId)
        .eq('learning_path_id', featuredPath.id)
        .single();

      if (userProgress) {
        isEnrolled = true;
        progressPercentage = topicsCountNum > 0
          ? Math.round((userProgress.topics_completed / topicsCountNum) * 100)
          : 0;
      }
    }

    const path = buildLearningPathResponse(
      featuredPath,
      topicsCountNum,
      isEnrolled,
      progressPercentage,
      localized.title,
      localized.description
    );

    return createRecommendedPathResponse(path, 'featured');
  } catch (error) {
    console.error('[RECOMMENDED_PATH] Error:', error);
    throw new AppError('SERVER_ERROR', 'Failed to get recommended learning path', 500);
  }
}

// ============================================================================
// Export
// ============================================================================

// Use createFunction to allow anonymous users to browse paths
// Authentication is only required for enrollment (handled in handleEnroll)
createFunction(handleLearningPaths, {
  allowedMethods: ['GET', 'POST'],
  enableAnalytics: true,
  timeout: 15000,
});
