import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  calculatePathScores,
  validateQuestionnaireResponses,
  type LearningPath,
  type QuestionnaireResponses,
} from './scoring-algorithm.ts'

const path = (slug: string, order: number, featured = false): LearningPath => ({
  id: `id-${slug}`,
  slug,
  title: slug,
  disciple_level: 'seeker',
  recommended_mode: 'standard',
  is_featured: featured,
  display_order: order,
})

const PATHS: LearningPath[] = [
  path('new-believer-essentials', 1, true),
  path('rooted-in-christ', 2, true),
  path('growing-in-discipleship', 3),
  path('defending-your-faith', 4, true),
  path('faith-and-family', 5, true),
  path('heart-for-the-world', 6),
  path('gospel-of-mark', 7),
]

const NEW: QuestionnaireResponses = {
  faith_stage: 'new_believer',
  spiritual_goals: ['foundational_faith'],
  time_availability: '5_to_10_min',
  learning_style: 'practical_application',
  life_stage_focus: 'personal_foundation',
  biggest_challenge: 'starting_basics',
}

const DOUBTS: QuestionnaireResponses = {
  faith_stage: 'committed_disciple',
  spiritual_goals: ['apologetics'],
  time_availability: '20_plus_min',
  learning_style: 'deep_understanding',
  life_stage_focus: 'intellectual_growth',
  biggest_challenge: 'handling_doubts',
}

Deno.test('answers change the top path', () => {
  assertEquals(calculatePathScores(NEW, PATHS, [])[0].pathSlug, 'new-believer-essentials')
  assertEquals(calculatePathScores(DOUBTS, PATHS, [])[0].pathSlug, 'defending-your-faith')
})

Deno.test('finished paths are never suggested', () => {
  const scored = calculatePathScores(DOUBTS, PATHS, ['id-defending-your-faith'])
  assertEquals(scored.some((s) => s.pathSlug === 'defending-your-faith'), false)
  assertEquals(scored.length, PATHS.length - 1)
})

Deno.test('every path finished leaves nothing to suggest', () => {
  assertEquals(calculatePathScores(NEW, PATHS, PATHS.map((p) => p.id)), [])
})

Deno.test('ties fall back to featured, then display order', () => {
  // gospel-of-mark is not in any mapping; with practical style every
  // standard path gets the same +20, so it ties at the bottom.
  const scored = calculatePathScores(NEW, PATHS, [])
  assertEquals(scored[scored.length - 1].pathSlug, 'gospel-of-mark')
})

Deno.test('validation rejects missing or extra goals and unknown values', () => {
  assertEquals(validateQuestionnaireResponses(NEW).isValid, true)
  assertEquals(validateQuestionnaireResponses({ ...NEW, spiritual_goals: [] }).isValid, false)
  assertEquals(
    validateQuestionnaireResponses({ ...NEW, spiritual_goals: ['theology', 'service', 'apologetics', 'relationships'] }).isValid,
    false,
  )
  // deno-lint-ignore no-explicit-any
  assertEquals(validateQuestionnaireResponses({ ...NEW, faith_stage: 'unknown' as any }).isValid, false)
  assertEquals(validateQuestionnaireResponses({ ...NEW, biggest_challenge: undefined }).isValid, false)
})
