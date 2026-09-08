// Run with: deno test path-progress.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { ACTIVE_PATH_CANDIDATES, effectiveProgress } from './path-progress.ts'

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
