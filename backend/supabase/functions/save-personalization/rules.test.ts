import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { scoringResultsFor, skipChangesFor } from './rules.ts'
import type { PathScore } from '../_shared/personalization/scoring-algorithm.ts'

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

Deno.test('no path left to suggest still saves, with no scoring results', () => {
  // A user who finished every path must still be able to save answers.
  assertEquals(scoringResultsFor([]), null)
})

Deno.test('scoring results lead with the top path', () => {
  const scored: PathScore[] = [
    { pathId: 'a', pathSlug: 'a-slug', pathTitle: 'A', score: 50, matchReasons: ['x'] },
    { pathId: 'b', pathSlug: 'b-slug', pathTitle: 'B', score: 10, matchReasons: [] },
  ]
  const results = scoringResultsFor(scored)!
  assertEquals(results.topMatch.pathSlug, 'a-slug')
  assertEquals(results.allScores.map((s) => s.pathSlug), ['a-slug', 'b-slug'])
})
