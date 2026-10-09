import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { flatListTotal, loadActivePathCount } from './list-total.ts'

Deno.test('the last page gives the exact total for any filter', () => {
  assertEquals(flatListTotal({ offset: 40, pageLength: 10, hasMore: false, activeCount: null, unfiltered: false }), 50)
  assertEquals(flatListTotal({ offset: 0, pageLength: 3, hasMore: false, activeCount: 50, unfiltered: false }), 3)
})

Deno.test('an unfiltered page with more uses the active-path count', () => {
  assertEquals(flatListTotal({ offset: 0, pageLength: 20, hasMore: true, activeCount: 50, unfiltered: true }), 50)
})

Deno.test('a filtered page with more, or a failed count, has no total', () => {
  assertEquals(flatListTotal({ offset: 0, pageLength: 20, hasMore: true, activeCount: 50, unfiltered: false }), null)
  assertEquals(flatListTotal({ offset: 0, pageLength: 20, hasMore: true, activeCount: null, unfiltered: true }), null)
})

Deno.test('a count that contradicts the page is not trusted', () => {
  assertEquals(flatListTotal({ offset: 40, pageLength: 10, hasMore: true, activeCount: 50, unfiltered: true }), null)
})

function countClient(result: { count: number | null; error: unknown }) {
  const calls: unknown[] = []
  const client = {
    from(table: string) {
      calls.push(['from', table])
      return {
        select(cols: string, opts: unknown) {
          calls.push(['select', cols, opts])
          return {
            eq(col: string, val: unknown) {
              calls.push(['eq', col, val])
              return Promise.resolve(result)
            },
          }
        },
      }
    },
  }
  return { client, calls }
}

Deno.test('loadActivePathCount counts active paths with a head request', async () => {
  const { client, calls } = countClient({ count: 50, error: null })
  assertEquals(await loadActivePathCount(client), 50)
  assertEquals(calls, [
    ['from', 'learning_paths'],
    ['select', 'id', { count: 'exact', head: true }],
    ['eq', 'is_active', true],
  ])
})

Deno.test('loadActivePathCount returns null on error', async () => {
  const { client } = countClient({ count: null, error: { message: 'x' } })
  assertEquals(await loadActivePathCount(client), null)
})
