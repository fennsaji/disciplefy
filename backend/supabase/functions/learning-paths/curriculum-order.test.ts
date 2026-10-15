import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { inCurriculumOrder } from './curriculum-order.ts'

Deno.test('paths sort by level, then display order, then the incoming order', () => {
  const rows = [
    { path_id: 'leader-a', disciple_level: 'leader', display_order: 1 },
    { path_id: 'seeker-2', disciple_level: 'seeker', display_order: 2 },
    { path_id: 'believer-1', disciple_level: 'believer', display_order: 1 },
    { path_id: 'seeker-1', disciple_level: 'seeker', display_order: 1 },
    { path_id: 'seeker-unordered', disciple_level: 'seeker' },
    { path_id: 'unknown', disciple_level: 'other', display_order: 0 },
  ]
  assertEquals(inCurriculumOrder(rows).map((r) => r.path_id),
    ['seeker-1', 'seeker-2', 'seeker-unordered', 'believer-1', 'leader-a', 'unknown'])
})
