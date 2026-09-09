import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { checkCostCeiling, COST_CEILING_MESSAGE, dailyLimitUsd, resetDailyLimitCache } from './cost-ceiling.ts'

// deno-lint-ignore no-explicit-any -- a stand-in for the system_config lookup
const configReturning = (value: string | null): any => ({
  from: () => ({
    select: () => ({
      eq: () => ({
        eq: () => ({ maybeSingle: () => Promise.resolve({ data: value === null ? null : { value }, error: null }) }),
      }),
    }),
  }),
})

// deno-lint-ignore no-explicit-any -- a stand-in for the two tables the check reads
const dbReturning = (rows: unknown, error?: { message: string }, limit: string | null = null): any => ({
  from: (table: string) =>
    table === 'system_config'
      ? {
        select: () => ({
          eq: () => ({
            eq: () => ({
              maybeSingle: () => Promise.resolve({ data: limit === null ? null : { value: limit }, error: null }),
            }),
          }),
        }),
      }
      : {
        select: () => ({
          gte: () => ({
            not: () => Promise.resolve({ data: rows, error: error ?? null }),
          }),
        }),
      },
})

Deno.test('the limit falls back to $15 a day when nothing is configured', async () => {
  resetDailyLimitCache()
  Deno.env.delete('DAILY_COST_LIMIT_USD')
  assertEquals(await dailyLimitUsd(), 15)
})

Deno.test('the configured limit from admin wins over the fallback', async () => {
  resetDailyLimitCache()
  const db = configReturning('120')
  assertEquals(await dailyLimitUsd(db), 120)
})

Deno.test('a nonsense configured limit is ignored rather than trusted', async () => {
  resetDailyLimitCache()
  Deno.env.delete('DAILY_COST_LIMIT_USD')
  assertEquals(await dailyLimitUsd(configReturning('lots')), 15)
})

Deno.test('spend under the ceiling is allowed', async () => {
  resetDailyLimitCache()
  const result = await checkCostCeiling(dbReturning([{ llm_cost_usd: 1.5 }, { llm_cost_usd: 2 }]))
  assertEquals(result.withinBudget, true)
  assertEquals(result.spentUsd, 3.5)
})

Deno.test('spend at the ceiling stops generation', async () => {
  resetDailyLimitCache()
  const result = await checkCostCeiling(dbReturning([{ llm_cost_usd: 3 }], undefined, '3'))
  assertEquals(result.withinBudget, false)
  resetDailyLimitCache()
})

Deno.test('a metering failure allows generation rather than taking the product down', async () => {
  resetDailyLimitCache()
  const result = await checkCostCeiling(dbReturning(null, { message: 'connection lost' }))
  assertEquals(result.withinBudget, true)
})

Deno.test('the message tells the reader what is still open', () => {
  assertEquals(COST_CEILING_MESSAGE.includes('Learning-path studies are still available'), true)
})
