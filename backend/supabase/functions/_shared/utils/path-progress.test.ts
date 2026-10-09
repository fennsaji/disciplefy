// Run with: deno test path-progress.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { ACTIVE_PATH_CANDIDATES, effectiveProgress, getCompletedPathIds } from './path-progress.ts'

/**
 * A finished path kept coming back in For You. Completion is recorded in two
 * places — per-topic rows, and `user_learning_path_progress.completed_at` — and
 * the recommendation read only the first, so a path finished through a
 * fellowship reported 25% and was offered again as a fresh suggestion.
 */
Deno.test('a stored completion floors the computed progress', () => {
  const completed = new Set(['path-done'])
  // The exact case seen in the app: 2 of 8 topic rows, but the path is finished.
  assertEquals(effectiveProgress(25, 'path-done', completed), 100)
})

Deno.test('a partly-done path keeps its real progress', () => {
  assertEquals(effectiveProgress(42, 'path-open', new Set(['other'])), 42)
  assertEquals(effectiveProgress(0, 'path-open', new Set()), 0)
})

Deno.test('a path completed by topics alone still reads as complete', () => {
  assertEquals(effectiveProgress(100, 'path-open', new Set()), 100)
})

Deno.test('the active-path lookup considers more than one candidate', () => {
  // With one, a user whose newest row was a just-finished path fell through to
  // a generic recommendation while another study was still in progress.
  assertEquals(ACTIVE_PATH_CANDIDATES > 1, true)
})

// deno-lint-ignore no-explicit-any
function fakeClient(rpc: { data: any; error: any }, stored: string[]): any {
  const chain = {
    select: () => chain, eq: () => chain,
    not: () => Promise.resolve({ data: stored.map((id) => ({ learning_path_id: id })), error: null }),
  }
  return { rpc: () => Promise.resolve(rpc), from: () => chain }
}

/**
 * A path finished lesson by lesson but whose stored row still read
 * completed_at NULL (or that was never enrolled) was not "completed" to the
 * recommenders, so it was suggested again.
 */
Deno.test('finished paths include those finished lesson by lesson', async () => {
  const ids = await getCompletedPathIds(fakeClient({ data: [{ learning_path_id: 'romans' }, { learning_path_id: 'john' }], error: null }, ['john']), 'u')
  assertEquals([...ids].sort(), ['john', 'romans'])
})

Deno.test('without the RPC, stored completion is still used', async () => {
  const ids = await getCompletedPathIds(fakeClient({ data: null, error: { message: 'missing' } }, ['john']), 'u')
  assertEquals([...ids], ['john'])
})
