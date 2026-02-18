/**
 * Continue Learning Edge Function
 *
 * Returns in-progress topics for the "Continue Learning" section
 * Part of Phase 1: Foundation & Progress Tracking
 *
 * Features:
 * - Returns topics the user has started but not completed
 * - Includes progress data (time spent, XP potential)
 * - Supports multi-language content
 * - Orders by most recently accessed
 */

import { createAuthenticatedFunction } from "../_shared/core/function-factory.ts";
import { ServiceContainer } from "../_shared/core/services.ts";
import { UserContext } from "../_shared/types/index.ts";
import { AppError } from "../_shared/utils/error-handler.ts";
import type { SupportedLanguage } from "../_shared/services/llm-config/language-configs.ts";
import { generateCorrelationId } from "../_shared/utils/correlation-id.ts";

// ============================================================================
// Types
// ============================================================================

interface ContinueLearningRequest {
  language?: string;
  limit?: number;
}

interface InProgressTopic {
  topic_id: string;
  topic_title: string;
  topic_description: string;
  topic_category: string;
  started_at: string;
  time_spent_seconds: number;
  xp_value: number;
  learning_path_id: string | null;
  learning_path_name: string | null;
  position_in_path: number | null;
  total_topics_in_path: number | null;
  topics_completed_in_path: number | null;
  recommended_mode: string | null;
}

interface LocalizedInProgressTopic {
  topic_id: string;
  title: string;
  description: string;
  category: string;
  started_at: string;
  time_spent_seconds: number;
  xp_value: number;
  learning_path_id: string | null;
  learning_path_name: string | null;
  position_in_path: number | null;
  total_topics_in_path: number | null;
  topics_completed_in_path: number | null;
  recommended_mode: string | null;
}

// ============================================================================
// Configuration
// ============================================================================

const DEFAULT_LANGUAGE: SupportedLanguage = "en";
const DEFAULT_LIMIT = 5;
const MAX_LIMIT = 10;
const MIN_LIMIT = 1;
const ALLOWED_LANGUAGES: readonly SupportedLanguage[] = ["en", "hi", "ml"] as const;

// ============================================================================
// Input Validation
// ============================================================================

/**
 * Validates and sanitizes language code input
 */
function validateLanguage(languageInput: string | null): SupportedLanguage {
  if (!languageInput || typeof languageInput !== "string") {
    return DEFAULT_LANGUAGE;
  }

  const normalized = languageInput.trim().toLowerCase();

  if (ALLOWED_LANGUAGES.includes(normalized as SupportedLanguage)) {
    return normalized as SupportedLanguage;
  }

  return DEFAULT_LANGUAGE;
}

/**
 * Validates and sanitizes limit parameter
 */
function validateLimit(limitInput: string | null): number {
  if (!limitInput) {
    return DEFAULT_LIMIT;
  }

  const parsed = parseInt(limitInput, 10);

  if (Number.isNaN(parsed) || !Number.isFinite(parsed)) {
    return DEFAULT_LIMIT;
  }

  return Math.max(MIN_LIMIT, Math.min(parsed, MAX_LIMIT));
}

// ============================================================================
// Helper Functions
// ============================================================================

async function getLocalizedContent(
  services: ServiceContainer,
  topicId: string,
  language: string,
  fallbackTitle: string,
  fallbackDescription: string,
): Promise<{ title: string; description: string }> {
  if (language === "en") {
    return { title: fallbackTitle, description: fallbackDescription };
  }

  // Try to get localized content from recommended_topics_translations table
  // using lang_code column (not language_code)
  const { data: translation } = await services.supabaseServiceClient
    .from("recommended_topics_translations")
    .select("title, description")
    .eq("topic_id", topicId)
    .eq("lang_code", language)
    .single();

  if (translation) {
    return {
      title: translation.title || fallbackTitle,
      description: translation.description || fallbackDescription,
    };
  }

  return { title: fallbackTitle, description: fallbackDescription };
}

async function getLocalizedLearningPathName(
  services: ServiceContainer,
  learningPathId: string | null,
  language: string,
  fallbackName: string | null,
): Promise<string | null> {
  if (!learningPathId || !fallbackName) {
    return fallbackName;
  }

  if (language === "en") {
    return fallbackName;
  }

  // Try to get localized learning path name from learning_path_translations table
  const { data: translation } = await services.supabaseServiceClient
    .from("learning_path_translations")
    .select("title")
    .eq("learning_path_id", learningPathId)
    .eq("lang_code", language)
    .single();

  if (translation?.title) {
    return translation.title;
  }

  return fallbackName;
}

// ============================================================================
// Main Handler
// ============================================================================

async function handleContinueLearning(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext,
): Promise<Response> {
  // Require authentication
  if (!userContext || userContext.type !== "authenticated") {
    throw new AppError("UNAUTHORIZED", "Authentication required", 401);
  }

  const userId = userContext.userId!;

  // Parse and validate query parameters
  const url = new URL(req.url);
  const validatedLanguage = validateLanguage(url.searchParams.get("language"));
  const validatedLimit = validateLimit(url.searchParams.get("limit"));

  // Get in-progress topics using the database function
  const { data: inProgressTopics, error } = await services.supabaseServiceClient
    .rpc(
      "get_in_progress_topics",
      {
        p_user_id: userId,
        p_limit: validatedLimit,
      },
    );

  if (error) {
    const correlationId = generateCorrelationId();

    // Log sanitized error (no sensitive details exposed to console)
    console.error(
      "[continue-learning] Database query failed",
      {
        operation: "fetch-in-progress-topics",
        correlationId,
        userId: userId.substring(0, 8) + "...", // Partial ID for correlation only
      }
    );

    // Internal structured log for debugging (not exposed to client)
    // Full error details stored server-side for support team
    await services.analyticsLogger.logEvent(
      "database_error",
      {
        operation: "continue-learning:fetch-in-progress-topics",
        correlationId,
        userId,
        errorCode: error.code,
        // error.message and error.details logged server-side only
      },
      req.headers.get("x-forwarded-for"),
    );

    // Return generic error to client without exposing DB internals
    // Client sees: "Failed to fetch in-progress topics. Reference: <correlationId>"
    throw new AppError(
      "DATABASE_ERROR",
      `Failed to fetch in-progress topics. Reference: ${correlationId}`,
      500
    );
  }

  // If no in-progress topics, return empty array
  if (!inProgressTopics || inProgressTopics.length === 0) {
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          topics: [],
          total: 0,
        },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }

  // Localize content if needed
  const localizedTopics: LocalizedInProgressTopic[] = [];

  for (const topic of inProgressTopics) {
    const localized = await getLocalizedContent(
      services,
      topic.topic_id,
      validatedLanguage,
      topic.topic_title,
      topic.topic_description,
    );

    // Localize learning path name if present
    const localizedPathName = await getLocalizedLearningPathName(
      services,
      topic.learning_path_id,
      validatedLanguage,
      topic.learning_path_name,
    );

    localizedTopics.push({
      topic_id: topic.topic_id,
      title: localized.title,
      description: localized.description,
      category: topic.topic_category,
      started_at: topic.started_at,
      time_spent_seconds: topic.time_spent_seconds,
      xp_value: topic.xp_value,
      learning_path_id: topic.learning_path_id,
      learning_path_name: localizedPathName,
      position_in_path: topic.position_in_path,
      total_topics_in_path: topic.total_topics_in_path,
      topics_completed_in_path: topic.topics_completed_in_path,
      recommended_mode: topic.recommended_mode,
    });
  }

  // Log analytics
  await services.analyticsLogger.logEvent(
    "continue_learning_accessed",
    {
      user_id: userId,
      topics_count: localizedTopics.length,
      language: validatedLanguage,
    },
    req.headers.get("x-forwarded-for"),
  );

  // Log usage for profitability tracking (non-LLM, read-only feature)
  try {
    const userTier = await services.authService.getUserPlan(req);

    await services.usageLoggingService.logUsage({
      userId,
      tier: userTier,
      featureName: 'continue_learning',
      operationType: 'read',
      tokensConsumed: 0,
      requestMetadata: {
        language: validatedLanguage,
        topics_count: localizedTopics.length,
        limit: validatedLimit,
      },
      responseMetadata: {
        success: true,
        latency_ms: 0,
      },
    });
  } catch (usageLogError) {
    console.error('Usage logging failed:', usageLogError)
    // Don't fail the request if usage logging fails
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: {
        topics: localizedTopics,
        total: localizedTopics.length,
      },
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
}

// ============================================================================
// Create Function with Factory
// ============================================================================

createAuthenticatedFunction(handleContinueLearning, {
  allowedMethods: ["GET"],
  enableAnalytics: true,
  timeout: 15000,
});
