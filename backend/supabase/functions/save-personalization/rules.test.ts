import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { answersRow, responseData, skipChangesFor, validateQuestionnaireResponses } from './rules.ts'

const answers = {
  faith_stage: 'growing_believer',
  spiritual_goals: ['apologetics'],
  time_availability: '10_to_20_min',
  learning_style: 'deep_understanding',
  life_stage_focus: 'intellectual_growth',
  biggest_challenge: 'handling_doubts',
}

Deno.test('skip on a finished questionnaire changes nothing', () => {
  // Retake from Settings, then Close or Skip: the earlier answers must stay.
  assertEquals(skipChangesFor({ questionnaire_completed: true }), null)
})

Deno.test('skip with no answers marks the questionnaire skipped', () => {
  assertEquals(skipChangesFor(null), { questionnaire_completed: false, questionnaire_skipped: true })
  assertEquals(
    skipChangesFor({ questionnaire_completed: false }),
    { questionnaire_completed: false, questionnaire_skipped: true },
  )
})

Deno.test('older apps still send six answers: they are validated as before', () => {
  assertEquals(validateQuestionnaireResponses(answers), { isValid: true, errors: [] })
  assertEquals(validateQuestionnaireResponses({ ...answers, spiritual_goals: [] }).isValid, false)
  assertEquals(validateQuestionnaireResponses({ ...answers, faith_stage: 'x' }).errors, ['Invalid faith_stage'])
  assertEquals(validateQuestionnaireResponses(undefined).isValid, false)
})

Deno.test('the saved row keeps the answers and no longer writes scores', () => {
  const row = answersRow('u', answers, '2026-10-10T00:00:00.000Z')
  assertEquals(row.faith_stage, 'growing_believer')
  assertEquals(row.questionnaire_completed, true)
  assertEquals(row.questionnaire_skipped, false)
  assertEquals('scoring_results' in row, false)
})

Deno.test('responses keep the row older apps parse and add the goal', () => {
  const data = responseData({ faith_stage: 'new_believer', questionnaire_completed: true }, 'new_to_faith')
  assertEquals(data, { faith_stage: 'new_believer', questionnaire_completed: true, growth_goal: 'new_to_faith' })
  assertEquals(responseData(null, null), { growth_goal: null })
})
