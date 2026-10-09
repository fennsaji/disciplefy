// Run with: deno test -A topic-selector.for-you-path.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { selectTopicsForYouWithLearningPath } from './topic-selector.ts'

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
  const db = fakeSupabase({
    user_learning_path_progress: [
      { user_id: 'u', learning_path_id: 'romans', current_topic_position: 0, topics_completed: 0, completed_at: null,
        learning_paths: { id: 'romans', title: 'Romans', slug: 'romans', is_active: true } },
      { user_id: 'u', learning_path_id: 'john', current_topic_position: 1, topics_completed: 1, completed_at: null,
        learning_paths: { id: 'john', title: 'John', slug: 'john', is_active: true } },
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
