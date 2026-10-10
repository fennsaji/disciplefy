// Run with: deno test -A topic-selector.for-you-path.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { selectTopicsForYouWithLearningPath } from './topic-selector.ts'
import { clearNextPathCaches } from './personalization/next-paths.ts'

type Row = Record<string, unknown>

/** Minimal PostgREST-like fake: top-level eq/in/is filters, everything else passes through. */
// deno-lint-ignore no-explicit-any
function fakeSupabase(tables: Record<string, Row[]>, rpcs: Record<string, unknown> = {}): any {
  const query = (table: string) => {
    let rows = [...(tables[table] ?? [])]
    let single = false
    const q: Record<string, unknown> = {
      select: () => q,
      eq: (col: string, v: unknown) => { if (!col.includes('.')) rows = rows.filter((r) => r[col] === v); return q },
      in: (col: string, vs: unknown[]) => { if (!col.includes('.')) rows = rows.filter((r) => vs.includes(r[col])); return q },
      is: (col: string, v: unknown) => { if (!col.includes('.')) rows = rows.filter((r) => (r[col] ?? null) === v); return q },
      not: () => q, order: () => q, limit: () => q, range: () => q, neq: () => q, or: () => q,
      single: () => { single = true; return q },
      maybeSingle: () => { single = true; return q },
      then: (resolve: (v: unknown) => void) =>
        resolve(single
          ? { data: rows[0] ?? null, error: rows[0] ? null : { code: 'PGRST116', message: 'none' } }
          : { data: rows, error: null, count: rows.length }),
    }
    return q
  }
  return {
    from: query,
    rpc: (name: string) => Promise.resolve({ data: rpcs[name] ?? [], error: null }),
  }
}

const topic = (id: string, title: string) => ({ id, title, description: '', category: 'Book Study', display_order: 0, is_active: true, xp_value: 50 })

/**
 * Romans is finished lesson by lesson, but its stored row (most recent
 * activity, e.g. from a Review) still reads completed_at NULL. The For You
 * section took only that one "active" row, found no lessons left, and fell
 * back to generic topics — never offering John, which is genuinely in progress.
 */
Deno.test('For You skips a finished-but-unmarked path and continues the next active one', async () => {
  clearNextPathCaches()
  const db = fakeSupabase({
    user_learning_path_progress: [
      { user_id: 'u', learning_path_id: 'romans', current_topic_position: 0, topics_completed: 0, completed_at: null, enrolled_at: 'x',
        learning_paths: { id: 'romans', title: 'Romans', slug: 'romans', is_active: true } },
      { user_id: 'u', learning_path_id: 'john', current_topic_position: 1, topics_completed: 1, completed_at: null, enrolled_at: 'x',
        learning_paths: { id: 'john', title: 'John', slug: 'john', is_active: true } },
    ],
    learning_paths: [
      { id: 'romans', slug: 'romans', title: 'Romans', is_active: true, is_featured: false, display_order: 1 },
      { id: 'john', slug: 'john', title: 'John', is_active: true, is_featured: false, display_order: 2 },
    ],
    learning_path_topics: [
      { learning_path_id: 'romans', topic_id: 'r1', position: 0, is_active: true, recommended_topics: topic('r1', 'Romans 1') },
      { learning_path_id: 'romans', topic_id: 'r2', position: 1, is_active: true, recommended_topics: topic('r2', 'Romans 2') },
      { learning_path_id: 'john', topic_id: 'j1', position: 0, is_active: true, recommended_topics: topic('j1', 'John 1') },
      { learning_path_id: 'john', topic_id: 'j2', position: 1, is_active: true, recommended_topics: topic('j2', 'John 2') },
    ],
    user_topic_progress: [
      { user_id: 'u', topic_id: 'r1' }, { user_id: 'u', topic_id: 'r2' }, { user_id: 'u', topic_id: 'j1' },
    ],
    user_study_guides: [],
    user_personalization: [],
  })

  const result = await selectTopicsForYouWithLearningPath('http://x', 'k', 'u', 2, db)
  assertEquals(result.suggestedLearningPath?.id, 'john')
  assertEquals(result.topics?.map((t) => t.title), ['John 2'])
})

/**
 * The goal drives the suggestion when nothing is in progress: the first path
 * of the goal list that is not finished, reported as 'personalized' (the value
 * older apps parse). A goal also counts as a finished questionnaire, so older
 * apps never show their questionnaire prompt to someone who picked a goal.
 */
Deno.test('For You suggests the goal list path when no path is active', async () => {
  clearNextPathCaches()
  const db = fakeSupabase({
    user_learning_path_progress: [],
    learning_paths: [
      { id: 'nbe', slug: 'new-believer-essentials', title: 'New Believer Essentials', is_active: true, is_featured: true, display_order: 1 },
      { id: 'rom', slug: 'romans-gospel-unfolded', title: 'Romans', is_active: true, is_featured: false, display_order: 16 },
      { id: 'gal', slug: 'galatians-gospel-freedom', title: 'Galatians', is_active: true, is_featured: false, display_order: 17 },
    ],
    growth_goal_paths: [
      { goal: 'understand_gospel', path_slug: 'romans-gospel-unfolded', position: 1 },
      { goal: 'understand_gospel', path_slug: 'galatians-gospel-freedom', position: 2 },
    ],
    user_growth_goals: [{ user_id: 'u', goal: 'understand_gospel' }],
    learning_path_topics: [
      { learning_path_id: 'rom', topic_id: 'r1', position: 0, is_active: true, recommended_topics: topic('r1', 'Romans 1') },
      { learning_path_id: 'gal', topic_id: 'g1', position: 0, is_active: true, recommended_topics: topic('g1', 'Galatians 1') },
    ],
    user_topic_progress: [],
    user_study_guides: [],
    user_personalization: [],
  }, { get_finished_path_ids: [{ learning_path_id: 'rom' }] })

  const result = await selectTopicsForYouWithLearningPath('http://x', 'k', 'u', 2, db)
  assertEquals(result.suggestedLearningPath?.id, 'gal')
  assertEquals(result.suggestedLearningPath?.reason, 'personalized')
  assertEquals(result.hasCompletedQuestionnaire, true)
})

Deno.test('For You without a goal suggests the default path and reports no questionnaire', async () => {
  clearNextPathCaches()
  const db = fakeSupabase({
    user_learning_path_progress: [],
    learning_paths: [
      { id: 'nbe', slug: 'new-believer-essentials', title: 'New Believer Essentials', is_active: true, is_featured: true, display_order: 1 },
    ],
    growth_goal_paths: [],
    user_growth_goals: [],
    learning_path_topics: [
      { learning_path_id: 'nbe', topic_id: 'n1', position: 0, is_active: true, recommended_topics: topic('n1', 'Who is Jesus?') },
    ],
    user_topic_progress: [],
    user_study_guides: [],
    user_personalization: [],
  })

  const result = await selectTopicsForYouWithLearningPath('http://x', 'k', 'u', 2, db)
  assertEquals(result.suggestedLearningPath?.id, 'nbe')
  assertEquals(result.suggestedLearningPath?.reason, 'default')
  assertEquals(result.hasCompletedQuestionnaire, false)
})
