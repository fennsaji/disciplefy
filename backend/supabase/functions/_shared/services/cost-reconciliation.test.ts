import { assertAlmostEquals, assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { reconcileDay, yesterdayUtc } from './cost-reconciliation.ts'

// deno-lint-ignore no-explicit-any -- a stand-in for the usage_logs query
const dbWithSpend = (rows: Array<{ llm_cost_usd: number }>): any => ({
  from: () => ({
    select: () => ({
      gte: () => ({
        lt: () => ({ not: () => Promise.resolve({ data: rows, error: null }) }),
      }),
    }),
  }),
})

Deno.test('yesterday is the previous UTC day', () => {
  assertEquals(yesterdayUtc(new Date('2026-09-09T00:30:00Z')), '2026-09-08')
  assertEquals(yesterdayUtc(new Date('2026-01-01T12:00:00Z')), '2025-12-31')
})

Deno.test('without an admin key it reports unconfigured rather than agreement', async () => {
  Deno.env.delete('ANTHROPIC_ADMIN_KEY')
  Deno.env.delete('ANTHROPIC_WORKSPACE_ID')

  const result = await reconcileDay(dbWithSpend([{ llm_cost_usd: 1.25 }]), '2026-09-08')

  assertEquals(result.configured, false)
  // Our own side is still measured, so the row is not empty.
  assertAlmostEquals(result.ourUsd, 1.25, 1e-9)
  // A gap of zero here means "not checked", which `configured` makes explicit.
  assertEquals(result.gapUsd, 0)
  assertEquals(typeof result.reason, 'string')
})

Deno.test('our own spend is summed across the day', async () => {
  const result = await reconcileDay(
    dbWithSpend([{ llm_cost_usd: 0.1 }, { llm_cost_usd: 0.25 }, { llm_cost_usd: 0.05 }]),
    '2026-09-08',
  )
  assertAlmostEquals(result.ourUsd, 0.4, 1e-9)
})
