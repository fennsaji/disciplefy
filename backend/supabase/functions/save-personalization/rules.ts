/**
 * Pure rules of the save-personalization function, kept apart from the
 * handler so they can be tested without a server.
 *
 * The 6-step questionnaire was retired on 2026-10-10 (the growth goal is the
 * only personalisation question). This endpoint stays for older apps: it still
 * validates and stores their answers, and turns them into a growth goal.
 */

export interface QuestionnaireResponses {
  faith_stage: string
  spiritual_goals: string[]
  time_availability: string
  learning_style: string
  life_stage_focus: string
  biggest_challenge: string
}

export interface ValidationResult {
  isValid: boolean
  errors: string[]
}

const FAITH_STAGES = ['new_believer', 'growing_believer', 'committed_disciple']
const SPIRITUAL_GOALS = ['foundational_faith', 'spiritual_depth', 'relationships', 'apologetics', 'service', 'theology']
const TIMES = ['5_to_10_min', '10_to_20_min', '20_plus_min']
const STYLES = ['practical_application', 'deep_understanding', 'reflection_meditation', 'balanced_approach']
const FOCUSES = ['personal_foundation', 'family_relationships', 'community_impact', 'intellectual_growth']
const CHALLENGES = ['starting_basics', 'staying_consistent', 'handling_doubts', 'sharing_faith', 'growing_stagnant']

/** The same checks older apps were built against (and the table enforces). */
export function validateQuestionnaireResponses(
  responses: Partial<QuestionnaireResponses> | null | undefined,
): ValidationResult {
  const r = responses ?? {}
  const errors: string[] = []
  const oneOf = (value: unknown, allowed: string[]) => typeof value === 'string' && allowed.includes(value)

  if (!oneOf(r.faith_stage, FAITH_STAGES)) errors.push('Invalid faith_stage')
  if (!Array.isArray(r.spiritual_goals)) {
    errors.push('spiritual_goals must be an array')
  } else if (r.spiritual_goals.length < 1 || r.spiritual_goals.length > 3) {
    errors.push('spiritual_goals must have 1-3 selections')
  } else if (!r.spiritual_goals.every((g) => SPIRITUAL_GOALS.includes(g))) {
    errors.push('Invalid spiritual_goals values')
  }
  if (!oneOf(r.time_availability, TIMES)) errors.push('Invalid time_availability')
  if (!oneOf(r.learning_style, STYLES)) errors.push('Invalid learning_style')
  if (!oneOf(r.life_stage_focus, FOCUSES)) errors.push('Invalid life_stage_focus')
  if (!oneOf(r.biggest_challenge, CHALLENGES)) errors.push('Invalid biggest_challenge')

  return { isValid: errors.length === 0, errors }
}

/** The user_personalization row a `save` writes. scoring_results is no longer written. */
export function answersRow(userId: string, data: QuestionnaireResponses, now: string) {
  return {
    user_id: userId,
    faith_stage: data.faith_stage,
    spiritual_goals: data.spiritual_goals,
    time_availability: data.time_availability,
    learning_style: data.learning_style,
    life_stage_focus: data.life_stage_focus,
    biggest_challenge: data.biggest_challenge,
    questionnaire_completed: true,
    questionnaire_skipped: false,
    updated_at: now,
  }
}

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
  if (existing?.questionnaire_completed === true) return null
  return { questionnaire_completed: false, questionnaire_skipped: true }
}

/** The `data` of a response: the row older apps parse, plus the growth goal. */
export function responseData(
  row: Record<string, unknown> | null,
  goal: string | null,
): Record<string, unknown> {
  return { ...(row ?? {}), growth_goal: goal }
}
