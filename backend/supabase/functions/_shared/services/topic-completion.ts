/**
 * Recording a learning-path lesson (topic) completion, and the follow-up work
 * a first completion triggers.
 *
 * Two endpoints record completions: topic-progress (`complete`, sent by the
 * client when the guide was opened with a topic id) and
 * mark-study-guide-complete (which resolves the topic from the guide). The
 * client fires both for a path lesson, in either order, so the follow-up hooks
 * run from whichever call recorded the first completion:
 *   - score recalculation runs only on the call whose RPC reported
 *     `is_first_completion` (complete_topic_progress lets exactly one caller
 *     win), so it runs once per real first completion;
 *   - fellowship auto-advance runs on every call; it is idempotent (it needs
 *     every member done and updates with an optimistic lock on the index).
 */

import { getCompletedPathIds } from '../utils/path-progress.ts'
import {
  calculatePathScores,
  getScoringResultsSummary,
  type LearningPath as ScoringLearningPath,
  type QuestionnaireResponses,
} from '../personalization/scoring-algorithm.ts'

// deno-lint-ignore no-explicit-any -- supabase-js client, not narrowed here
type Client = any

export interface TopicCompletionRecord {
  progress_id: string
  xp_earned: number
  is_first_completion: boolean
  topic_title: string
}

export interface FellowshipAdvanceResult {
  fellowship_id: string
  new_guide_index: number
  study_completed: boolean
}

/** How long after a completion another call still reports it as just completed. */
export const RECENT_COMPLETION_WINDOW_MS = 2 * 60 * 1000

// ============================================================================
// Pure decisions
// ============================================================================

/** Which follow-up hooks to run after a completion RPC returned [isFirstCompletion]. */
export function completionHookPlan(isFirstCompletion: boolean): {
  recalculateScores: boolean
  autoAdvanceFellowship: boolean
} {
  return { recalculateScores: isFirstCompletion, autoAdvanceFellowship: true }
}

/** True when the learning_path_topics row at the study's index is [topicId]. */
export function lessonTopicMatches(
  row: { id?: string; topic_id?: string | null } | null | undefined,
  topicId: string,
): boolean {
  return !!row && row.topic_id === topicId
}

/** The study state after every member finished the lesson at [currentIndex]. */
export function nextFellowshipStudyState(
  currentIndex: number,
  totalTopics: number,
): { isComplete: boolean; newGuideIndex: number } {
  const nextIndex = currentIndex + 1
  const isComplete = nextIndex >= totalTopics
  return { isComplete, newGuideIndex: isComplete ? currentIndex : nextIndex }
}

/**
 * Position of the lesson whose completion last moved this study: the current
 * index once the study is complete (the index is not bumped then), otherwise
 * the previous one. Null when the study has not moved.
 */
export function advancedLessonPosition(study: {
  current_guide_index: number
  completed_at: string | null
}): number | null {
  if (study.completed_at) return study.current_guide_index
  return study.current_guide_index > 0 ? study.current_guide_index - 1 : null
}

export function isRecentCompletion(
  completedAt: string | null | undefined,
  now: Date,
  windowMs: number = RECENT_COMPLETION_WINDOW_MS,
): boolean {
  if (!completedAt) return false
  const at = Date.parse(completedAt)
  if (Number.isNaN(at)) return false
  return now.getTime() - at <= windowMs
}

/**
 * What topic-progress reports for a completion. When its own RPC saw an
 * already-completed topic but that completion happened moments ago (recorded
 * by mark-study-guide-complete for the same lesson), the client is told it was
 * the first completion, with the XP stored for it.
 */
export function reportedCompletion(
  record: TopicCompletionRecord,
  stored: { completed_at: string | null; xp_earned: number | null } | null,
  now: Date,
): TopicCompletionRecord {
  if (record.is_first_completion || !stored || !isRecentCompletion(stored.completed_at, now)) {
    return record
  }
  return { ...record, xp_earned: stored.xp_earned ?? 0, is_first_completion: true }
}

// ============================================================================
// Recording
// ============================================================================

/**
 * Marks [topicId] complete for the user. The containing learning path is
 * ensured started first, so the completion trigger counts this lesson's XP
 * and progress in the path row. Guests are never auto-enrolled: a guest holds
 * one path, enrolled through learning-paths, which enforces the guest rules.
 * Throws when the completion RPC fails; the path ensure is best effort.
 */
export async function recordTopicCompletion(
  db: Client,
  params: { userId: string; topicId: string; timeSpentSeconds: number; isGuest: boolean },
): Promise<TopicCompletionRecord> {
  const { userId, topicId, timeSpentSeconds, isGuest } = params

  if (!isGuest) {
    await ensureLearningPathStarted(db, userId, topicId)
  }

  const { data, error } = await db.rpc('complete_topic_progress', {
    p_user_id: userId,
    p_topic_id: topicId,
    p_time_spent_seconds: timeSpentSeconds,
  })
  if (error) {
    throw new Error(`complete_topic_progress failed: ${error.message}`)
  }

  const row = Array.isArray(data) ? data[0] : data
  if (!row) {
    throw new Error('complete_topic_progress returned no row')
  }
  return {
    progress_id: row.progress_id,
    xp_earned: row.xp_earned,
    is_first_completion: row.is_first_completion,
    topic_title: row.topic_title,
  }
}

/**
 * Best effort: make sure the learning path containing this topic is marked
 * started for the user (prefers a path an active fellowship of theirs is
 * studying). Never throws. Callers skip it for guests.
 */
export async function ensureLearningPathStarted(
  db: Client,
  userId: string,
  topicId: string,
): Promise<void> {
  try {
    const { error } = await db.rpc('ensure_learning_path_started', {
      p_user_id: userId,
      p_topic_id: topicId,
    })
    if (error) {
      console.warn('[topic-completion] ensure_learning_path_started failed:', error.message)
    }
  } catch (err) {
    console.warn(
      '[topic-completion] ensure_learning_path_started skipped:',
      err instanceof Error ? err.message : 'unknown error',
    )
  }
}

/** The stored completion of [topicId] for the user, or null. */
export async function loadStoredCompletion(
  db: Client,
  userId: string,
  topicId: string,
): Promise<{ completed_at: string | null; xp_earned: number | null } | null> {
  try {
    const { data } = await db
      .from('user_topic_progress')
      .select('completed_at, xp_earned')
      .eq('user_id', userId)
      .eq('topic_id', topicId)
      .maybeSingle()
    return data ?? null
  } catch {
    return null
  }
}

/**
 * Runs the follow-up hooks for a completion: score recalculation on the first
 * completion, fellowship auto-advance always. Never throws.
 */
export async function runCompletionHooks(
  db: Client,
  userId: string,
  topicId: string,
  isFirstCompletion: boolean,
): Promise<FellowshipAdvanceResult | null> {
  const plan = completionHookPlan(isFirstCompletion)
  if (plan.recalculateScores) {
    await maybeTriggerScoreRecalculation(db, userId)
  }
  return plan.autoAdvanceFellowship ? await maybeTriggerFellowshipAutoAdvance(db, userId, topicId) : null
}

// ============================================================================
// Score recalculation
// ============================================================================

/**
 * Recalculates personalization scores after a first completion, when a learning
 * path was just completed (completed_at in the last 10 seconds) or the user's
 * completed topic count reached a multiple of 10. Non-fatal.
 */
export async function maybeTriggerScoreRecalculation(db: Client, userId: string): Promise<void> {
  try {
    // The completion trigger runs inside the complete_topic_progress RPC, so a
    // newly finished path already has completed_at set here.
    const { data: justCompletedPaths } = await db
      .from('user_learning_path_progress')
      .select('learning_path_id')
      .eq('user_id', userId)
      .not('completed_at', 'is', null)
      .gte('completed_at', new Date(Date.now() - 10_000).toISOString())

    const pathJustCompleted = (justCompletedPaths || []).length > 0

    const { count: completedCount } = await db
      .from('user_topic_progress')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .not('completed_at', 'is', null)

    const isMilestone =
      typeof completedCount === 'number' && completedCount > 0 && completedCount % 10 === 0

    if (!pathJustCompleted && !isMilestone) return

    const triggerReason = pathJustCompleted ? 'path_completion' : 'topic_milestone'
    console.log(`[topic-completion] Score recalculation triggered (${triggerReason})`)

    const { data: personalization } = await db
      .from('user_personalization')
      .select(
        'faith_stage, spiritual_goals, time_availability, learning_style, life_stage_focus, biggest_challenge, questionnaire_completed',
      )
      .eq('user_id', userId)
      .single()

    if (!personalization?.questionnaire_completed || !personalization.faith_stage) return

    const { data: allPaths } = await db
      .from('learning_paths')
      .select('id, slug, title, disciple_level, recommended_mode, is_featured, display_order')
      .eq('is_active', true)
      .order('display_order', { ascending: true })

    if (!allPaths || allPaths.length === 0) return

    // Finished paths: stored completion or every visible lesson done.
    const completedPathIds = [...await getCompletedPathIds(db, userId)]

    const responses: QuestionnaireResponses = {
      faith_stage: personalization.faith_stage as QuestionnaireResponses['faith_stage'],
      spiritual_goals: personalization.spiritual_goals || [],
      time_availability: personalization.time_availability as QuestionnaireResponses['time_availability'],
      learning_style: personalization.learning_style as QuestionnaireResponses['learning_style'],
      life_stage_focus: personalization.life_stage_focus as QuestionnaireResponses['life_stage_focus'],
      biggest_challenge: personalization.biggest_challenge as QuestionnaireResponses['biggest_challenge'],
    }

    const scoredPaths = calculatePathScores(responses, allPaths as ScoringLearningPath[], completedPathIds)
    if (!scoredPaths || scoredPaths.length === 0) return

    const topPath = scoredPaths[0]
    const scoringSummary = getScoringResultsSummary(topPath, scoredPaths)

    const { error: updateError } = await db
      .from('user_personalization')
      .update({ scoring_results: scoringSummary, updated_at: new Date().toISOString() })
      .eq('user_id', userId)

    if (updateError) {
      console.warn('[topic-completion] Failed to update scoring_results:', updateError.message)
    }
  } catch (err) {
    console.warn(
      '[topic-completion] Score recalculation error (non-fatal):',
      err instanceof Error ? err.message : 'unknown error',
    )
  }
}

// ============================================================================
// Fellowship auto-advance
// ============================================================================

interface FellowshipStudyRow {
  id: string
  fellowship_id: string
  learning_path_id: string
  current_guide_index: number
  completed_at?: string | null
  updated_at?: string | null
}

async function activeFellowshipIds(db: Client, userId: string): Promise<string[]> {
  const { data: memberships } = await db
    .from('fellowship_members')
    .select('fellowship_id')
    .eq('user_id', userId)
    .eq('is_active', true)
  return ((memberships || []) as Array<{ fellowship_id: string }>).map((m) => m.fellowship_id)
}

async function lessonAt(db: Client, pathId: string, position: number) {
  const { data } = await db
    .from('learning_path_topics')
    .select('topic_id')
    .eq('learning_path_id', pathId)
    .eq('position', position)
    .eq('is_active', true)
    .maybeSingle()
  return data as { topic_id: string } | null
}

/**
 * Advances each active fellowship study whose current lesson is [topicId] once
 * every active member has completed it. Idempotent: the update is conditioned
 * on the index it read, so a concurrent or repeated call does nothing.
 * Non-fatal: returns null on any error.
 */
export async function maybeTriggerFellowshipAutoAdvance(
  db: Client,
  userId: string,
  topicId: string,
): Promise<FellowshipAdvanceResult | null> {
  try {
    const fellowshipIds = await activeFellowshipIds(db, userId)
    if (fellowshipIds.length === 0) return null

    const { data: studies } = await db
      .from('fellowship_study')
      .select('id, fellowship_id, learning_path_id, current_guide_index')
      .in('fellowship_id', fellowshipIds)
      .is('completed_at', null)

    for (const study of (studies || []) as FellowshipStudyRow[]) {
      const lesson = await lessonAt(db, study.learning_path_id, study.current_guide_index)
      if (!lessonTopicMatches(lesson, topicId)) continue

      // Muted members are included: muting restricts posting, not study.
      const { data: members } = await db
        .from('fellowship_members')
        .select('user_id')
        .eq('fellowship_id', study.fellowship_id)
        .eq('is_active', true)
      if (!members || members.length === 0) continue
      const memberUserIds = (members as Array<{ user_id: string }>).map((m) => m.user_id)

      const { count: completedCount } = await db
        .from('user_topic_progress')
        .select('id', { count: 'exact', head: true })
        .eq('topic_id', topicId)
        .in('user_id', memberUserIds)
        .not('completed_at', 'is', null)
      if (completedCount !== memberUserIds.length) continue

      const { count: totalTopics } = await db
        .from('learning_path_topics')
        .select('id', { count: 'exact', head: true })
        .eq('learning_path_id', study.learning_path_id)
        .eq('is_active', true)
      if (!totalTopics) continue

      const next = nextFellowshipStudyState(study.current_guide_index, totalTopics)
      const nowIso = new Date().toISOString()
      const updateData = next.isComplete
        ? { completed_at: nowIso, updated_at: nowIso }
        : { current_guide_index: next.newGuideIndex, updated_at: nowIso }

      const { data: updatedRows, error: updateError } = await db
        .from('fellowship_study')
        .update(updateData)
        .eq('id', study.id)
        .eq('current_guide_index', study.current_guide_index)
        .is('completed_at', null)
        .select('id')

      if (updateError) {
        console.warn('[topic-completion] Fellowship auto-advance update error (non-fatal):', updateError.message)
        continue
      }
      if (!updatedRows || updatedRows.length === 0) continue // another request advanced it

      return {
        fellowship_id: study.fellowship_id,
        new_guide_index: next.newGuideIndex,
        study_completed: next.isComplete,
      }
    }
    return null
  } catch (err) {
    console.warn(
      '[topic-completion] Fellowship auto-advance error (non-fatal):',
      err instanceof Error ? err.message : 'unknown error',
    )
    return null
  }
}

/**
 * A fellowship study this user is in that moved past [topicId] within the
 * recent window (advanced by the other completion endpoint), reported the
 * same way as an advance made now. Null when none. Non-fatal.
 */
export async function findRecentFellowshipAdvance(
  db: Client,
  userId: string,
  topicId: string,
  now: Date,
): Promise<FellowshipAdvanceResult | null> {
  try {
    const fellowshipIds = await activeFellowshipIds(db, userId)
    if (fellowshipIds.length === 0) return null

    const { data: studies } = await db
      .from('fellowship_study')
      .select('id, fellowship_id, learning_path_id, current_guide_index, completed_at, updated_at')
      .in('fellowship_id', fellowshipIds)
      .gte('updated_at', new Date(now.getTime() - RECENT_COMPLETION_WINDOW_MS).toISOString())

    for (const study of (studies || []) as FellowshipStudyRow[]) {
      const position = advancedLessonPosition({
        current_guide_index: study.current_guide_index,
        completed_at: study.completed_at ?? null,
      })
      if (position === null) continue
      const lesson = await lessonAt(db, study.learning_path_id, position)
      if (!lessonTopicMatches(lesson, topicId)) continue
      return {
        fellowship_id: study.fellowship_id,
        new_guide_index: study.current_guide_index,
        study_completed: !!study.completed_at,
      }
    }
    return null
  } catch {
    return null
  }
}
