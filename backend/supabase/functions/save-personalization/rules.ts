/**
 * Pure rules of the save-personalization function, kept apart from the
 * handler so they can be tested without a server.
 */

import { getScoringResultsSummary, type PathScore } from '../_shared/personalization/scoring-algorithm.ts';

/**
 * Columns a "skip" writes, or null to leave the row alone.
 *
 * A finished questionnaire stays finished: Retake from Settings followed by
 * Close or Skip used to set questionnaire_completed back to false, and every
 * recommendation fell back to the default path.
 */
export function skipChangesFor(
  existing: { questionnaire_completed?: boolean | null } | null,
): { questionnaire_completed: false; questionnaire_skipped: true } | null {
  if (existing?.questionnaire_completed === true) return null;
  return { questionnaire_completed: false, questionnaire_skipped: true };
}

/**
 * The stored scoring summary, or null when no path is left to suggest (every
 * path finished). The answers are still saved in that case.
 */
export function scoringResultsFor(
  scoredPaths: PathScore[],
): ReturnType<typeof getScoringResultsSummary> | null {
  if (scoredPaths.length === 0) return null;
  return getScoringResultsSummary(scoredPaths[0], scoredPaths);
}
