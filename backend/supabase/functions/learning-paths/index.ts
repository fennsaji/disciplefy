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
import { checkFeatureAccess } from '../_shared/middleware/feature-access-middleware.ts';
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts';
import { TtlCache } from '../_shared/utils/ttl-cache.ts';
import { buildRecommendedExtras, type NextLessonJson } from './next-lesson.ts';
import { flatListTotal, loadActivePathCount } from './list-total.ts';
import { loadCategorySummaries } from './category-summaries.ts';
import {
  assertGuestMayEnroll,
  loadGuestAccessiblePathIds,
  loadPathGuestAccessible,
  loadUserEnrolledPathIds,
  parseEnrollTarget,
  resolvePathIdBySlug,
} from './guest-rules.ts';
import {
  loadCompletedTopicCounts,
  loadEnrolledPathIds,
  loadNextLessonNumbers,
  loadPathTranslations,
  pathProgressPercentage,
  resolveShortTitle,
  type PathTranslation,
} from './batch-loaders.ts';
import {
  legacyPathReason,
  loadNextPaths,
  type NextPath,
  type NextPathReason,
} from '../_shared/personalization/next-paths.ts';

// ============================================================================
// Types
// ============================================================================

interface LearningPathsRequest {
  language?: string;
  includeEnrolled?: boolean;
  limit?: number;
  offset?: number;
  /** New category-grouped list params */
  categoryLimit?: number;
  categoryOffset?: number;
  /** format='flat' keeps the legacy flat-list response for internal use */
  format?: 'flat' | 'categories';
  /** Optional search term — filters by title/description via ILIKE */
  search?: string;
  /** Optional fellowship ID — when provided, marks paths completed by this fellowship */
  fellowship_id?: string;
}

interface CategoryPathsRequest {
  action: 'category_paths';
  category: string;
  language?: string;
  limit?: number;
  offset?: number;
}

interface LearningPathCategoryResult {
  name: string;
  paths: LearningPath[];
  total_in_category: number;
  has_more_in_category: boolean;
}

interface LearningPathDetailRequest {
  pathId: string;
  language?: string;
}

interface LearningPath {
  id: string;
  slug: string;
  title: string;
  /** Localized display name (<= 28 chars) for headers and rows; null = use title. */
  short_title: string | null;
  description: string;
  icon_name: string;
  color: string;
  total_xp: number;
  estimated_days: number;
  disciple_level: string;
  recommended_mode?: string;
  is_featured: boolean;
  /** True when a guest may enrol in and study this path. */
  guest_accessible: boolean;
  topics_count: number;
  is_enrolled: boolean;
  progress_percentage: number;
  topics_completed: number;
  category: string;
  /** Curated order within a disciple level (admin-set). */
  display_order?: number;
  /** Localized title of the first unfinished topic; recommended path only. */
  next_topic_title?: string;
  /** First incomplete lesson; null when finished. Recommended path only. */
  next_lesson?: NextLessonJson | null;
  /**
   * 1-based number of the first unfinished lesson, from the lesson rows; null
   * when finished. List endpoints, signed-in users only (absent otherwise).
   */
  next_lesson_number?: number | null;
  /** 1-based lesson numbers of milestones. Recommended path only. */
  milestone_positions?: number[];
}

interface LearningPathDetail extends LearningPath {
  allow_non_sequential_access: boolean;
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
  short_title?: string | null;
  description: string;
  icon_name: string;
  color: string;
  total_xp: number;
  estimated_days: number;
  disciple_level: string;
  is_featured: boolean;
  is_active: boolean;
  guest_accessible?: boolean;
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
/**
 * Active-topic counts per learning path, shared across requests in this worker.
 *
 * Every section of a response — active paths, featured, recommended — asks for
 * the same handful of paths, and each ask was its own round trip. Counts are
 * catalogue data (the same for every user), so they live for ten minutes; an
 * admin edit to a path's topics shows up within that window. User progress is
 * never cached here.
 */
const CATALOG_CACHE_TTL_MS = 10 * 60 * 1000;
const topicCountCache = new TtlCache<number>(CATALOG_CACHE_TTL_MS, 2000);

/**
 * Path translations keyed by `${pathId}:${lang}`; null records "no row", so a
 * missing translation is not re-queried on every request.
 */
const translationCache = new TtlCache<PathTranslation>(
  CATALOG_CACHE_TTL_MS,
  2000,
);

/**
 * Counts every path in [learningPathIds] in one query, filling the cache.
 *
 * Callers that know their paths up front should use this; getTopicsCount then
 * answers from memory.
 */
async function preloadTopicCounts(
  // deno-lint-ignore no-explicit-any -- the client type is not narrowed here
  supabaseClient: any,
  learningPathIds: string[]
): Promise<void> {
  const missing = learningPathIds.filter((id) => id && !topicCountCache.has(id));
  if (missing.length === 0) return;

  const { data, error } = await supabaseClient
    .from('learning_path_topics')
    .select('learning_path_id')
    .in('learning_path_id', missing)
    .eq('is_active', true);

  // A failed read is not remembered as "zero topics" for ten minutes;
  // getTopicsCount falls back to its own query for these paths.
  if (error) return;

  const counts = new Map<string, number>();
  for (const id of missing) counts.set(id, 0);
  for (const row of (data ?? []) as Array<{ learning_path_id: string }>) {
    counts.set(row.learning_path_id, (counts.get(row.learning_path_id) ?? 0) + 1);
  }
  for (const [id, count] of counts) topicCountCache.set(id, count);
}

async function getTopicsCount(
  supabaseClient: ReturnType<ServiceContainer['supabaseServiceClient']['from']> extends (...args: any[]) => any ? any : any,
  learningPathId: string
): Promise<number> {
  const cached = topicCountCache.get(learningPathId);
  if (cached !== undefined) return cached;

  const { data, error } = await supabaseClient
    .from('learning_path_topics')
    .select('id', { count: 'exact' })
    .eq('learning_path_id', learningPathId)
    .eq('is_active', true);

  const count = data?.length || 0;
  if (!error) topicCountCache.set(learningPathId, count);
  return count;
}

/**
 * Counts the actual number of completed topics for a user in a learning path
 * by joining learning_path_topics with user_topic_progress.
 * This is the authoritative count (not the stale denormalized counter).
 */
async function getActualTopicsCompleted(
  supabaseClient: ReturnType<ServiceContainer['supabaseServiceClient']['from']> extends (...args: any[]) => any ? any : any,
  learningPathId: string,
  userId: string
): Promise<number> {
  // There is no FK between learning_path_topics and user_topic_progress, so an
  // embedded join fails with PGRST200 and silently yields 0. Query separately.
  const { data: pathTopics, error: topicsError } = await supabaseClient
    .from('learning_path_topics')
    .select('topic_id')
    .eq('learning_path_id', learningPathId)
    .eq('is_active', true);

  if (topicsError) {
    console.error('[LEARNING_PATHS] Failed to load path topics:', topicsError);
    return 0;
  }
  const topicIds = (pathTopics || []).map((t: { topic_id: string }) => t.topic_id);
  if (topicIds.length === 0) return 0;

  const { data: completed, error: progressError } = await supabaseClient
    .from('user_topic_progress')
    .select('topic_id')
    .eq('user_id', userId)
    .in('topic_id', topicIds)
    .not('completed_at', 'is', null);

  if (progressError) {
    console.error('[LEARNING_PATHS] Failed to load topic progress:', progressError);
    return 0;
  }
  // Distinct, in case a topic ever has more than one progress row.
  return new Set((completed || []).map((r: { topic_id: string }) => r.topic_id)).size;
}

/** A path's title, description and short display title in one language. */
interface LocalizedPathText {
  title: string;
  description: string;
  shortTitle: string | null;
}

/**
 * Gets localized title, description and short title for a learning path.
 * [fallbackShortTitle] is the path's own (English) short_title.
 */
async function getLocalizedTitleDescription(
  supabaseClient: ReturnType<ServiceContainer['supabaseServiceClient']['from']> extends (...args: any[]) => any ? any : any,
  learningPathId: string,
  language: string,
  fallbackTitle: string,
  fallbackDescription: string,
  fallbackShortTitle?: string | null
): Promise<LocalizedPathText> {
  if (language === 'en') {
    return {
      title: fallbackTitle,
      description: fallbackDescription,
      shortTitle: resolveShortTitle(language, fallbackShortTitle, undefined),
    };
  }

  const cacheKey = `${learningPathId}:${language}`;
  let translation = translationCache.get(cacheKey);
  if (translation === undefined) {
    const { data, error } = await supabaseClient
      .from('learning_path_translations')
      .select('title, description, short_title')
      .eq('learning_path_id', learningPathId)
      .eq('lang_code', language)
      .single();

    const row = (data ?? null) as PathTranslation;
    translation = row;
    // Remember a found row, or a confirmed absence (PGRST116: no rows). Any
    // other error is transient and must not pin the English fallback.
    if (row || error?.code === 'PGRST116') {
      translationCache.set(cacheKey, row);
    }
  }

  const shortTitle = resolveShortTitle(language, fallbackShortTitle, translation);
  if (translation) {
    return {
      title: translation.title || fallbackTitle,
      description: translation.description || fallbackDescription,
      shortTitle,
    };
  }

  return { title: fallbackTitle, description: fallbackDescription, shortTitle };
}

/**
 * Fills translationCache for every path in [learningPathIds] with one query,
 * so getLocalizedTitleDescription answers from memory afterwards.
 */
async function preloadTranslations(
  // deno-lint-ignore no-explicit-any -- the client type is not narrowed here
  supabaseClient: any,
  learningPathIds: string[],
  language: string
): Promise<void> {
  if (language === 'en') return;
  const missing = learningPathIds.filter((id) => id && !translationCache.has(`${id}:${language}`));
  if (missing.length === 0) return;
  const rows = await loadPathTranslations(supabaseClient, missing, language);
  // On error nothing is cached; getLocalizedTitleDescription queries per path.
  if (!rows) return;
  for (const [id, row] of rows) translationCache.set(`${id}:${language}`, row);
}

/**
 * Each path's own (English) short_title, keyed by path id; catalogue data,
 * cached like the rest. Null records "none set".
 */
const baseShortTitleCache = new TtlCache<string | null>(CATALOG_CACHE_TTL_MS, 2000);

/**
 * Localized short titles for paths that come from the RPCs (which return the
 * localized title but not the short one): two batched reads at most, then
 * memory. A failed read yields null short titles (the client shows the title)
 * and is not cached.
 */
async function loadShortTitles(
  // deno-lint-ignore no-explicit-any -- the client type is not narrowed here
  supabaseClient: any,
  learningPathIds: string[],
  language: string
): Promise<Map<string, string | null>> {
  const ids = [...new Set(learningPathIds.filter(Boolean))];
  const missing = ids.filter((id) => !baseShortTitleCache.has(id));
  await Promise.all([
    (async () => {
      if (missing.length === 0) return;
      const { data, error } = await supabaseClient
        .from('learning_paths')
        .select('id, short_title')
        .in('id', missing);
      if (error) {
        console.warn('[LearningPaths] short_title lookup failed; using titles');
        return;
      }
      for (const id of missing) baseShortTitleCache.set(id, null);
      for (const row of (data ?? []) as Array<{ id: string; short_title: string | null }>) {
        baseShortTitleCache.set(row.id, row.short_title ?? null);
      }
    })(),
    preloadTranslations(supabaseClient, ids, language),
  ]);
  const result = new Map<string, string | null>();
  for (const id of ids) {
    const translation = language === 'en' ? undefined : (translationCache.get(`${id}:${language}`) ?? null);
    result.set(id, resolveShortTitle(language, baseShortTitleCache.get(id) ?? null, translation));
  }
  return result;
}

/**
 * Everything the recommended-path handler needs per candidate path, fetched
 * for all candidates at once and in parallel: topic counts and translations
 * (into the catalogue caches), plus the user's completed-topic counts and
 * enrollments (per request, never cached).
 *
 * A null map means that batch read failed; callers then fall back to the
 * per-path lookups, which keeps the previous behaviour on errors.
 */
async function preloadCandidateData(
  // deno-lint-ignore no-explicit-any -- the client type is not narrowed here
  supabaseClient: any,
  learningPathIds: string[],
  userId: string | null | undefined,
  language: string
): Promise<{ completed: Map<string, number> | null; enrolled: Set<string> | null }> {
  const [, , completed, enrolled] = await Promise.all([
    preloadTopicCounts(supabaseClient, learningPathIds),
    preloadTranslations(supabaseClient, learningPathIds, language),
    userId ? loadCompletedTopicCounts(supabaseClient, learningPathIds, userId) : Promise.resolve(null),
    userId ? loadEnrolledPathIds(supabaseClient, learningPathIds, userId) : Promise.resolve(null),
  ]);
  return { completed, enrolled };
}

/** Completed-topic count from the preloaded map, or a per-path query. */
async function completedFor(
  // deno-lint-ignore no-explicit-any -- the client type is not narrowed here
  supabaseClient: any,
  completed: Map<string, number> | null,
  learningPathId: string,
  userId: string
): Promise<number> {
  const known = completed?.get(learningPathId);
  if (known !== undefined) return known;
  return await getActualTopicsCompleted(supabaseClient, learningPathId, userId);
}

/**
 * Builds a LearningPath response object from path data
 */
function buildLearningPathResponse(
  pathData: Record<string, any>,
  topicsCount: number,
  isEnrolled: boolean,
  progressPercentage: number,
  localized: LocalizedPathText,
  topicsCompleted?: number
): LearningPath {
  return {
    id: pathData.id,
    slug: pathData.slug,
    title: localized.title,
    short_title: localized.shortTitle,
    description: localized.description,
    icon_name: pathData.icon_name,
    color: pathData.color,
    total_xp: pathData.total_xp,
    estimated_days: pathData.estimated_days,
    disciple_level: pathData.disciple_level,
    is_featured: pathData.is_featured,
    guest_accessible: pathData.guest_accessible === true,
    topics_count: topicsCount,
    is_enrolled: isEnrolled,
    progress_percentage: progressPercentage,
    topics_completed: topicsCompleted ?? (topicsCount > 0 ? Math.round(progressPercentage * topicsCount / 100) : 0),
    category: (pathData as Record<string, unknown>).category as string || '',
  };
}

/**
 * Adds next_lesson, topics_completed, milestone_positions (and the legacy
 * next_topic_title) to the recommended path. Topics and localized titles come
 * from get_learning_path_details, the same lookup the detail endpoint uses.
 * Guests get the same shape with nothing completed. Best effort: any failure
 * returns the path unchanged (older apps ignore the new fields).
 */
async function withNextTopic(
  // deno-lint-ignore no-explicit-any -- the client type is not narrowed here
  supabaseClient: any,
  path: LearningPath | null,
  userId: string | null | undefined,
  language: string
): Promise<LearningPath | null> {
  if (!path) return path;
  try {
    const { data, error } = await supabaseClient.rpc('get_learning_path_details', {
      p_path_id: path.id,
      p_user_id: userId ?? null,
      p_language: language,
    });
    if (error || !data || data.length === 0) return path;
    const extras = buildRecommendedExtras(data[0].topics, !!userId, path.title);
    const enriched: LearningPath = { ...path, ...extras };
    if (extras.next_lesson) enriched.next_topic_title = extras.next_lesson.title;
    enriched.next_lesson_number = extras.next_lesson?.lesson_number ?? null;
    return enriched;
  } catch (e) {
    console.error('[RECOMMENDED_PATH] Next lesson lookup failed:', e instanceof Error ? e.message : 'unknown');
    return path;
  }
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
  // Check maintenance mode FIRST
  await checkMaintenanceMode(req, services)

  const url = new URL(req.url);
  const pathSegments = url.pathname.split('/').filter(Boolean);

  // NOTE: We do NOT check feature access here for read operations (viewing paths)
  // This allows users to see learning paths with lock overlays in the frontend
  // Feature access is only checked for write operations (enrollment) below

  // The user's plan only matters for enrollment; handleEnroll resolves it there.

  // Determine the action based on URL pattern and method
  // /learning-paths -> list paths
  // /learning-paths?pathId=xxx -> get path details (via query param)
  // /learning-paths/enroll -> enroll in path
  // /learning-paths?action=recommended -> get recommended path for user

  const method = req.method.toUpperCase();
  const action = url.searchParams.get('action');

  // Check if this is a recommended paths (plural) request
  if ((method === 'GET' || method === 'POST') && action === 'categories') {
    return handleListCategories(services, userContext);
  }

  if ((method === 'GET' || method === 'POST') && action === 'recommended_paths') {
    return handleGetRecommendedPaths(req, services, userContext);
  }

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

    // For POST, also check the body for routing
    if (method === 'POST') {
      try {
        const clonedReq = req.clone();
        const body = await clonedReq.json();
        if (body.pathId) {
          return handleGetPathDetails(req, services, userContext, body.pathId, body.language);
        }
        if (body.action === 'categories') {
          return handleListCategories(services, userContext);
        }
        if (body.action === 'category_paths') {
          return handleListPathsByCategory(req, services, userContext);
        }
        if (body.format === 'flat') {
          return handleListPathsFlat(req, services, userContext);
        }
      } catch {
        // If body parsing fails, continue to category-grouped list
      }
    }

    // Otherwise return category-grouped paths (primary endpoint)
    return handleListPaths(req, services, userContext);
  }

  throw new AppError('INVALID_REQUEST', 'Method not allowed', 405);
}

// ============================================================================
// Shared helper
// ============================================================================

/**
 * Ids of the guest-accessible paths, shared across requests in this worker for
 * labelling responses only (catalogue data, same for every caller). Enrolment
 * reads the flag fresh. A failed lookup is not cached and labels nothing.
 */
const guestAccessibleCache = new TtlCache<Set<string>>(CATALOG_CACHE_TTL_MS, 1);

/** Number of active paths, cached like the rest of the catalogue. */
const activePathCountCache = new TtlCache<number>(CATALOG_CACHE_TTL_MS, 1);

// deno-lint-ignore no-explicit-any -- supabase-js client, not narrowed here
async function activePathCount(client: any): Promise<number | null> {
  const cached = activePathCountCache.get('count');
  if (cached !== undefined) return cached;
  const count = await loadActivePathCount(client);
  if (count === null) {
    console.warn('[LearningPaths] active path count failed; list total unknown');
    return null;
  }
  activePathCountCache.set('count', count);
  return count;
}

// deno-lint-ignore no-explicit-any -- supabase-js client, not narrowed here
async function guestAccessiblePathIds(client: any): Promise<Set<string>> {
  const cached = guestAccessibleCache.get('ids');
  if (cached) return cached;
  const ids = await loadGuestAccessiblePathIds(client);
  if (!ids) {
    console.warn('[LearningPaths] guest_accessible lookup failed; labelling no path');
    return new Set();
  }
  guestAccessibleCache.set('ids', ids);
  return ids;
}

function mapPathRow(
  row: Record<string, unknown>,
  guestAccessibleIds: Set<string>,
  shortTitles: Map<string, string | null>,
): LearningPath {
  return {
    id: row.path_id as string,
    slug: row.slug as string,
    title: row.title as string,
    short_title: shortTitles.get(row.path_id as string) ?? null,
    description: row.description as string,
    icon_name: row.icon_name as string,
    color: row.color as string,
    total_xp: row.total_xp as number,
    estimated_days: row.estimated_days as number,
    disciple_level: row.disciple_level as string,
    is_featured: row.is_featured as boolean,
    guest_accessible: guestAccessibleIds.has(row.path_id as string),
    topics_count: row.total_topics as number,
    is_enrolled: row.is_enrolled as boolean,
    progress_percentage: row.progress_percentage as number,
    topics_completed: (row.topics_completed as number) ??
      (row.total_topics && row.progress_percentage
        ? Math.round((row.progress_percentage as number) * (row.total_topics as number) / 100)
        : 0),
    category: row.category as string,
    display_order: row.display_order as number | undefined,
  };
}

/**
 * Adds next_lesson_number to list rows for a signed-in user. Best effort: on
 * a failed read the field is left out and the app falls back to its count.
 */
async function withNextLessonNumbers<T extends LearningPath>(
  // deno-lint-ignore no-explicit-any -- the client type is not narrowed here
  supabaseClient: any,
  paths: T[],
  userId: string | null | undefined,
): Promise<T[]> {
  if (!userId || paths.length === 0) return paths;
  const numbers = await loadNextLessonNumbers(supabaseClient, paths.map((p) => p.id), userId);
  if (!numbers) return paths;
  return paths.map((p) => (numbers.has(p.id) ? { ...p, next_lesson_number: numbers.get(p.id) ?? null } : p));
}

// ============================================================================
// List Learning Paths — category-grouped (primary) + flat (legacy)
// ============================================================================

/**
 * Category-grouped list (new primary endpoint).
 *
 * Returns N categories (default 4) each with up to PATHS_PER_CATEGORY (3) paths.
 * One extra category is fetched to detect hasMoreCategories.
 * One extra path per category is fetched to detect hasMoreInCategory.
 * All per-category path queries run in parallel via Promise.all.
 */
async function handleListPaths(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  const { supabaseServiceClient } = services;
  const PATHS_PER_CATEGORY = 3;
  const DEFAULT_CATEGORY_LIMIT = 4;

  let language = 'en';
  let includeEnrolled = true;
  let categoryLimit = DEFAULT_CATEGORY_LIMIT;
  let categoryOffset = 0;

  if (req.method === 'POST') {
    try {
      const body: LearningPathsRequest = await req.json();
      language = body.language || 'en';
      includeEnrolled = body.includeEnrolled ?? true;
      categoryLimit = typeof body.categoryLimit === 'number' ? body.categoryLimit : DEFAULT_CATEGORY_LIMIT;
      categoryOffset = typeof body.categoryOffset === 'number' ? body.categoryOffset : 0;
    } catch {
      // Use defaults
    }
  } else {
    const url = new URL(req.url);
    language = url.searchParams.get('language') || 'en';
    includeEnrolled = url.searchParams.get('includeEnrolled') !== 'false';
    categoryLimit = parseInt(url.searchParams.get('categoryLimit') || String(DEFAULT_CATEGORY_LIMIT), 10) || DEFAULT_CATEGORY_LIMIT;
    categoryOffset = parseInt(url.searchParams.get('categoryOffset') || '0', 10) || 0;
  }

  const userId = userContext?.type === 'authenticated' ? userContext.userId : null;

  // Step 1: fetch categories in priority order (limit+1 for hasMore detection)
  const { data: catData, error: catError } = await supabaseServiceClient.rpc(
    'get_learning_path_categories',
    { p_user_id: userId, p_limit: categoryLimit + 1, p_offset: categoryOffset }
  );

  if (catError) {
    console.error('Error fetching categories:', catError);
    throw new AppError('DATABASE_ERROR', 'Failed to fetch learning path categories', 500);
  }

  const allCats = catData || [];
  const hasMoreCategories = allCats.length > categoryLimit;
  const pageCategories = hasMoreCategories ? allCats.slice(0, categoryLimit) : allCats;

  if (pageCategories.length === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        data: { categories: [], has_more_categories: false, next_category_offset: categoryOffset },
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  }

  // Step 2: fetch paths for every category in parallel
  const [guestIds, ...pathResults] = await Promise.all([
    guestAccessiblePathIds(supabaseServiceClient),
    ...pageCategories.map((cat: Record<string, unknown>) =>
      supabaseServiceClient.rpc('get_available_learning_paths', {
        p_user_id: userId,
        p_language: language,
        p_include_enrolled: includeEnrolled,
        p_limit: PATHS_PER_CATEGORY + 1,
        p_offset: 0,
        p_category: cat.category as string,
      })
    ),
  ]);

  // Short titles for every path on the page, in one batch.
  const pageRows = (pathResults as Array<{ data: Record<string, unknown>[] | null }>)
    .flatMap((r) => r.data ?? []);
  const shortTitles = await loadShortTitles(
    supabaseServiceClient,
    pageRows.map((r) => r.path_id as string),
    language,
  );

  // Next unfinished lesson per path on the page, in one batch.
  const nextNumbers = userId
    ? await loadNextLessonNumbers(supabaseServiceClient, pageRows.map((r) => r.path_id as string), userId)
    : null;

  // Step 3: build response
  const categories: LearningPathCategoryResult[] = pageCategories.map(
    (cat: Record<string, unknown>, i: number) => {
      const { data: pathRows, error: pathErr } = pathResults[i] as {
        data: Record<string, unknown>[] | null;
        error: unknown;
      };
      if (pathErr) {
        console.error(`Error fetching paths for category ${cat.category}:`, pathErr);
      }
      const rows: Record<string, unknown>[] = pathRows || [];
      const hasMoreInCategory = rows.length > PATHS_PER_CATEGORY;
      const paths = (hasMoreInCategory ? rows.slice(0, PATHS_PER_CATEGORY) : rows)
        .map((row) => mapPathRow(row, guestIds, shortTitles))
        .map((p) => (nextNumbers?.has(p.id) ? { ...p, next_lesson_number: nextNumbers.get(p.id) ?? null } : p));

      return {
        name: cat.category as string,
        paths,
        total_in_category: cat.total_paths as number,
        has_more_in_category: hasMoreInCategory,
      };
    }
  );

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        categories,
        has_more_categories: hasMoreCategories,
        next_category_offset: categoryOffset + pageCategories.length,
      },
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

/**
 * Flat-list variant kept for internal use (getEnrolledPaths, etc.).
 * Triggered by body.format === 'flat'.
 */
async function handleListPathsFlat(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  const { supabaseServiceClient } = services;
  const PAGE_SIZE = 50;

  let language = 'en';
  let includeEnrolled = true;
  let limit = PAGE_SIZE;
  let offset = 0;
  let search: string | undefined;
  let fellowshipId: string | undefined;

  try {
    const body: LearningPathsRequest = await req.json();
    language = body.language || 'en';
    includeEnrolled = body.includeEnrolled ?? true;
    limit = typeof body.limit === 'number' ? body.limit : PAGE_SIZE;
    offset = typeof body.offset === 'number' ? body.offset : 0;
    search = body.search?.trim() || undefined;
    fellowshipId = body.fellowship_id || undefined;
  } catch {
    // Use defaults
  }

  const userId = userContext?.type === 'authenticated' ? userContext.userId : null;

  const rpcParams: Record<string, unknown> = {
    p_user_id: userId,
    p_language: language,
    p_include_enrolled: includeEnrolled,
    p_limit: limit + 1,
    p_offset: offset,
  };
  if (search) rpcParams['p_search'] = search;

  const unfiltered = !search && includeEnrolled;
  const [{ data, error }, guestIds, activeCount] = await Promise.all([
    supabaseServiceClient.rpc('get_available_learning_paths', rpcParams),
    guestAccessiblePathIds(supabaseServiceClient),
    unfiltered ? activePathCount(supabaseServiceClient) : Promise.resolve(null),
  ]);

  if (error) {
    console.error('Error fetching learning paths (flat):', error);
    throw new AppError('DATABASE_ERROR', 'Failed to fetch learning paths', 500);
  }

  // If a fellowship_id was provided, determine which paths this fellowship has completed.
  // Sources: completed_path_ids array (historical) + current path if completed_at is set.
  const completedPathIds = new Set<string>();
  if (fellowshipId) {
    const { data: studyRow } = await supabaseServiceClient
      .from('fellowship_study')
      .select('learning_path_id, completed_at, completed_path_ids')
      .eq('fellowship_id', fellowshipId)
      .maybeSingle();
    if (studyRow) {
      const historical = (studyRow.completed_path_ids as string[]) ?? [];
      for (const id of historical) completedPathIds.add(id);
      if (studyRow.completed_at) completedPathIds.add(studyRow.learning_path_id as string);
    }
  }

  const rows = data || [];
  const hasMore = rows.length > limit;
  const pageRows: Record<string, unknown>[] = hasMore ? rows.slice(0, limit) : rows;
  const shortTitles = await loadShortTitles(
    supabaseServiceClient,
    pageRows.map((r) => r.path_id as string),
    language,
  );
  const paths = await withNextLessonNumbers(supabaseServiceClient, pageRows.map((row: Record<string, unknown>) => ({
    ...mapPathRow(row, guestIds, shortTitles),
    fellowship_completed: completedPathIds.has(row.path_id as string),
  })), userId);

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        paths,
        // Matching paths in the whole list (null when unknown), not the page size.
        total: flatListTotal({ offset, pageLength: paths.length, hasMore, activeCount, unfiltered }),
        has_more: hasMore,
        offset,
      },
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

// ============================================================================
// Every category with its path count (no paths)
// ============================================================================

/**
 * Every category with its active-path count, in the user's priority order.
 * Body `{ action: 'categories' }` or `?action=categories`. Paths are not
 * loaded: All paths shows every category chip before listing any path.
 */
async function handleListCategories(
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  const userId = userContext?.type === 'authenticated' ? userContext.userId : null;
  const categories = await loadCategorySummaries(services.supabaseServiceClient, userId ?? null);
  if (!categories) {
    console.error('[LearningPaths] category summaries failed');
    throw new AppError('DATABASE_ERROR', 'Failed to fetch learning path categories', 500);
  }
  return new Response(
    JSON.stringify({ success: true, data: { categories } }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

// ============================================================================
// Load more paths for a specific category
// ============================================================================

/**
 * Returns the next page of paths for a single category.
 * Body: { action: 'category_paths', category, language, offset, limit }
 */
async function handleListPathsByCategory(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  const { supabaseServiceClient } = services;
  const DEFAULT_LIMIT = 3;

  let language = 'en';
  let category = '';
  let offset = 0;
  let limit = DEFAULT_LIMIT;

  try {
    const body: CategoryPathsRequest = await req.json();
    language = body.language || 'en';
    category = body.category || '';
    offset = typeof body.offset === 'number' ? body.offset : 0;
    limit = typeof body.limit === 'number' ? body.limit : DEFAULT_LIMIT;
  } catch {
    // Use defaults
  }

  if (!category) {
    throw new AppError('VALIDATION_ERROR', 'category is required', 400);
  }

  const userId = userContext?.type === 'authenticated' ? userContext.userId : null;

  const [{ data, error }, guestIds] = await Promise.all([
    supabaseServiceClient.rpc('get_available_learning_paths', {
      p_user_id: userId,
      p_language: language,
      p_include_enrolled: true,
      p_limit: limit + 1,
      p_offset: offset,
      p_category: category,
    }),
    guestAccessiblePathIds(supabaseServiceClient),
  ]);

  if (error) {
    console.error(`Error fetching paths for category ${category}:`, error);
    throw new AppError('DATABASE_ERROR', 'Failed to fetch category paths', 500);
  }

  const rows = data || [];
  const hasMore = rows.length > limit;
  const pageRows: Record<string, unknown>[] = hasMore ? rows.slice(0, limit) : rows;
  const shortTitles = await loadShortTitles(
    supabaseServiceClient,
    pageRows.map((r) => r.path_id as string),
    language,
  );
  const paths = await withNextLessonNumbers(
    supabaseServiceClient,
    pageRows.map((row) => mapPathRow(row, guestIds, shortTitles)),
    userId,
  );

  return new Response(
    JSON.stringify({ success: true, data: { paths, has_more: hasMore, category, offset } }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
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
  const [{ data, error }, guestIds, shortTitles] = await Promise.all([
    supabaseServiceClient.rpc('get_learning_path_details', {
      p_path_id: resolvedPathId,
      p_user_id: userId,
      p_language: language,
    }),
    guestAccessiblePathIds(supabaseServiceClient),
    loadShortTitles(supabaseServiceClient, [resolvedPathId], language),
  ]);

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
    short_title: shortTitles.get(row.path_id) ?? null,
    description: row.description,
    icon_name: row.icon_name,
    color: row.color,
    total_xp: row.total_xp,
    estimated_days: row.estimated_days,
    disciple_level: row.disciple_level,
    recommended_mode: row.recommended_mode,
    allow_non_sequential_access: row.allow_non_sequential_access,
    category: (row.category as string) || '',
    is_featured: false,
    guest_accessible: guestIds.has(row.path_id),
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

  if (!userContext.userId) {
    throw new AppError('UNAUTHORIZED', 'Invalid user context', 401);
  }

  // Check feature access for WRITE operations (enrollment)
  const userPlan = await services.authService.getUserPlan(req);
  await checkFeatureAccess(userContext.userId, userPlan, 'learning_paths', userContext.email);
  console.log(`✅ [LearningPaths] Feature access granted for enrollment: learning_paths available for plan ${userPlan}`);

  const { supabaseServiceClient } = services;

  // Parse request: { pathId } or { slug }; a pathId query param still works.
  let body: unknown = null;
  try {
    body = await req.json();
  } catch {
    // No JSON body: fall back to the query parameter below.
  }
  const target = parseEnrollTarget(body, new URL(req.url).searchParams.get('pathId'));
  const pathId = 'pathId' in target
    ? target.pathId
    : await resolvePathIdBySlug(supabaseServiceClient, target.slug);

  // A guest holds one guest-accessible path: the first one, which they may
  // re-enrol. Any other path needs an account.
  if (userContext.isGuest) {
    const [guestAccessible, enrolledPathIds] = await Promise.all([
      loadPathGuestAccessible(supabaseServiceClient, pathId),
      loadUserEnrolledPathIds(supabaseServiceClient, userContext.userId),
    ]);
    assertGuestMayEnroll(enrolledPathIds, pathId, guestAccessible);
  }

  // Call the database function (returns progress_id UUID)
  const { data: progressId, error } = await supabaseServiceClient.rpc('enroll_in_learning_path', {
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

  if (!progressId) {
    throw new AppError('DATABASE_ERROR', 'Failed to create enrollment record', 500);
  }

  // Fetch the enrollment details
  const { data: enrollmentDetails, error: fetchError } = await supabaseServiceClient
    .from('user_learning_path_progress')
    .select('id, learning_path_id, enrolled_at')
    .eq('id', progressId)
    .single();

  if (fetchError || !enrollmentDetails) {
    console.error('Error fetching enrollment details:', fetchError);
    throw new AppError('DATABASE_ERROR', 'Failed to fetch enrollment details', 500);
  }

  const result: EnrollmentResult = {
    id: enrollmentDetails.id,
    learning_path_id: enrollmentDetails.learning_path_id,
    enrolled_at: enrollmentDetails.enrolled_at,
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
// Get Recommended Learning Paths (plural) and the single recommended path
// ============================================================================
//
// Both come from the one next-path engine (_shared/personalization/next-paths.ts):
// active path, then the growth goal list, then featured, then the catalogue.
// Reasons keep the values older apps parse: a goal pick reports 'personalized'.

/** Language and limit from the body (POST) or the query string (GET). */
async function readRecommendationParams(
  req: Request,
  defaultLimit: number,
): Promise<{ language: string; limit: number }> {
  let language = 'en';
  let limit = defaultLimit;
  if (req.method === 'POST') {
    try {
      const body = await req.json() as { language?: string; limit?: number };
      language = body.language || 'en';
      if (typeof body.limit === 'number' && body.limit > 0) limit = body.limit;
    } catch { /* use defaults */ }
  } else {
    const url = new URL(req.url);
    language = url.searchParams.get('language') || 'en';
    const limitParam = parseInt(url.searchParams.get('limit') ?? '', 10);
    if (limitParam > 0) limit = limitParam;
  }
  return { language, limit: Math.min(Math.max(limit, 1), 20) };
}

/** The signed-in user (guests included) and whether they are a guest. */
function recommendationUser(userContext?: UserContext): { userId: string | null; isGuest: boolean } {
  const userId = userContext?.type === 'authenticated' ? userContext.userId ?? null : null;
  return { userId, isGuest: userId !== null && userContext?.isGuest === true };
}

/**
 * Response objects for the engine's picks, in order. Progress comes from
 * user_topic_progress floored by stored completion, as everywhere else; a pick
 * that turns out finished is dropped.
 */
async function buildEnginePaths(
  // deno-lint-ignore no-explicit-any -- the client type is not narrowed here
  supabaseClient: any,
  picks: NextPath[],
  userId: string | null,
  language: string,
  finishedIds: Set<string>,
  enrolledIds: Set<string>,
): Promise<{ path: LearningPath; reason: NextPathReason }[]> {
  const ids = picks.map((p) => p.pathId);
  if (ids.length === 0) return [];
  const [{ data: rows, error }, preload] = await Promise.all([
    supabaseClient.from('learning_paths').select('*').in('id', ids),
    preloadCandidateData(supabaseClient, ids, userId, language),
  ]);
  if (error) {
    console.error('[RECOMMENDED_PATH] Error fetching path rows:', error.message);
    return [];
  }
  // deno-lint-ignore no-explicit-any -- select('*') row
  const byId = new Map<string, any>((rows ?? []).map((r: { id: string }) => [r.id, r]));

  const out: { path: LearningPath; reason: NextPathReason }[] = [];
  for (const pick of picks) {
    const row = byId.get(pick.pathId);
    if (!row) continue;
    const topicsCount = await getTopicsCount(supabaseClient, row.id);
    const completed = userId ? await completedFor(supabaseClient, preload.completed, row.id, userId) : 0;
    const percentage = userId ? pathProgressPercentage(completed, topicsCount, row.id, finishedIds) : 0;
    if (userId && percentage >= 100) continue;
    const localized = await getLocalizedTitleDescription(
      supabaseClient, row.id, language, row.title, row.description, row.short_title
    );
    const isEnrolled = enrolledIds.has(row.id) || (preload.enrolled?.has(row.id) ?? false);
    out.push({
      path: buildLearningPathResponse(row, topicsCount, isEnrolled, percentage, localized, completed),
      reason: pick.reason,
    });
  }
  return out;
}

/**
 * Top N paths to suggest (Topics, the "What next?" card, "Choose your first
 * path"). Adds `finished_path` (id and title of the path the user just
 * finished, when nothing else is active) for the "What next?" card.
 */
async function handleGetRecommendedPaths(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext,
): Promise<Response> {
  const { supabaseServiceClient } = services;
  const { language, limit } = await readRecommendationParams(req, 5);
  const { userId, isGuest } = recommendationUser(userContext);

  // A few extra picks: one can still turn out finished by lesson count.
  const next = await loadNextPaths(supabaseServiceClient, { userId, isGuest, limit: limit + 3 });
  const built = (await buildEnginePaths(
    supabaseServiceClient, next.paths, userId, language, next.finishedIds, next.enrolledIds,
  )).slice(0, limit);

  let finishedPath: { id: string; title: string; short_title: string | null } | null = null;
  if (next.lastFinishedPathId) {
    const { data: row } = await supabaseServiceClient
      .from('learning_paths')
      .select('id, title, description, short_title')
      .eq('id', next.lastFinishedPathId)
      .maybeSingle();
    if (row) {
      const localized = await getLocalizedTitleDescription(
        supabaseServiceClient, row.id, language, row.title, row.description, row.short_title
      );
      finishedPath = { id: row.id, title: localized.title, short_title: localized.shortTitle };
    }
  }

  console.log(`[RECOMMENDED_PATHS] guest=${isGuest} goal=${next.goal ?? 'none'} count=${built.length}`);

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        paths: built.map((b) => b.path),
        reason: built.length > 0 ? legacyPathReason(built[0].reason) : 'featured',
        finished_path: finishedPath,
      },
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}

/**
 * The single recommended path (Home "Continue learning"): the engine's first
 * pick. When every path is finished, the default path is returned anyway so
 * older apps always have a path to show.
 */
async function handleGetRecommendedPath(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  const { supabaseServiceClient } = services;
  const { language } = await readRecommendationParams(req, 1);
  const { userId, isGuest } = recommendationUser(userContext);

  try {
    const next = await loadNextPaths(supabaseServiceClient, { userId, isGuest, limit: 4 });
    const built = await buildEnginePaths(
      supabaseServiceClient, next.paths, userId, language, next.finishedIds, next.enrolledIds,
    );
    const first = built[0];
    if (first) {
      console.log(`[RECOMMENDED_PATH] reason=${first.reason} guest=${isGuest}`);
      return createRecommendedPathResponse(
        await withNextTopic(supabaseServiceClient, first.path, userId, language),
        legacyPathReason(first.reason),
      );
    }

    // Everything finished (or nothing readable): the default path, as before.
    const { data: fallback } = await supabaseServiceClient
      .from('learning_paths')
      .select('*')
      .eq('slug', DEFAULT_FEATURED_PATH_SLUG)
      .eq('is_active', true)
      .maybeSingle();
    if (!fallback) return createRecommendedPathResponse(null, 'featured');

    const topicsCount = await getTopicsCount(supabaseServiceClient, fallback.id);
    const localized = await getLocalizedTitleDescription(
      supabaseServiceClient, fallback.id, language, fallback.title, fallback.description, fallback.short_title
    );
    const completed = userId
      ? await getActualTopicsCompleted(supabaseServiceClient, fallback.id, userId)
      : 0;
    const path = buildLearningPathResponse(
      fallback,
      topicsCount,
      next.enrolledIds.has(fallback.id),
      userId ? pathProgressPercentage(completed, topicsCount, fallback.id, next.finishedIds) : 0,
      localized,
      completed,
    );
    return createRecommendedPathResponse(
      await withNextTopic(supabaseServiceClient, path, userId, language),
      'featured'
    );
  } catch (error) {
    console.error('[RECOMMENDED_PATH] Error:', error instanceof Error ? error.message : 'unknown');
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
