import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { loadCategorySummaries, toCategorySummaries } from './category-summaries.ts'

Deno.test('every category is listed with its path count, in the given order', () => {
  assertEquals(
    toCategorySummaries([
      { category: 'Foundations', total_paths: 12 },
      { category: 'Gospels', total_paths: 3 },
      { category: 'Prophets', total_paths: 1 },
    ]),
    [
      { name: 'Foundations', total_paths: 12 },
      { name: 'Gospels', total_paths: 3 },
      { name: 'Prophets', total_paths: 1 },
    ],
  )
})

Deno.test('blank, empty and repeated categories are dropped', () => {
  assertEquals(
    toCategorySummaries([
      { category: '  ', total_paths: 2 },
      { category: null, total_paths: 2 },
      { category: 'Growth', total_paths: 0 },
      { category: 'Gospels', total_paths: 3 },
      { category: 'Gospels', total_paths: 3 },
      { category: 'Psalms', total_paths: '4' },
    ]),
    [
      { name: 'Gospels', total_paths: 3 },
      { name: 'Psalms', total_paths: 4 },
    ],
  )
})

Deno.test('no rows lists no categories', () => {
  assertEquals(toCategorySummaries(null), [])
})

Deno.test('loads every category in one request, not a page of them', async () => {
  let params: Record<string, unknown> | undefined
  const client = {
    rpc: (name: string, p: Record<string, unknown>) => {
      assertEquals(name, 'get_learning_path_categories')
      params = p
      return Promise.resolve({ data: [{ category: 'Gospels', total_paths: 3 }], error: null })
    },
  }
  const result = await loadCategorySummaries(client, 'user-1')
  assertEquals(result, [{ name: 'Gospels', total_paths: 3 }])
  assertEquals(params?.p_user_id, 'user-1')
  assertEquals(params?.p_offset, 0)
  assertEquals((params?.p_limit as number) >= 200, true)
})

Deno.test('a failed read is null, not an empty list', async () => {
  const client = {
    rpc: () => Promise.resolve({ data: null, error: { message: 'boom' } }),
  }
  assertEquals(await loadCategorySummaries(client, null), null)
})
