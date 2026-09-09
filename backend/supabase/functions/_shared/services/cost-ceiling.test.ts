import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { checkCostCeiling, COST_CEILING_MESSAGE, dailyLimitUsd } from './cost-ceiling.ts'

// deno-lint-ignore no-explicit-any -- a stand-in for the two calls the check makes
const dbReturning = (rows: unknown, error?: { message: string }): any => ({
  from: () => ({
    select: () => ({
      gte: () => ({
        not: () => Promise.resolve({ data: rows, error: error ?? null }),
      }),
    }),
  }),
})

Deno.test('the limit falls back to $50 a day when the environment says nothing', () => {
  Deno.env.delete('DAILY_COST_LIMIT_USD')
  assertEquals(dailyLimitUsd(), 50)
})

Deno.test('the limit can be raised deliberately', () => {
  Deno.env.set('DAILY_COST_LIMIT_USD', '120')
  assertEquals(dailyLimitUsd(), 120)
  Deno.env.delete('DAILY_COST_LIMIT_USD')
})

Deno.test('a nonsense limit is ignored rather than trusted', () => {
  Deno.env.set('DAILY_COST_LIMIT_USD', 'lots')
  assertEquals(dailyLimitUsd(), 50)
  Deno.env.delete('DAILY_COST_LIMIT_USD')
})

Deno.test('spend under the ceiling is allowed', async () => {
  const result = await checkCostCeiling(dbReturning([{ llm_cost_usd: 1.5 }, { llm_cost_usd: 2 }]))
  assertEquals(result.withinBudget, true)
  assertEquals(result.spentUsd, 3.5)
})

Deno.test('spend at the ceiling stops generation', async () => {
  Deno.env.set('DAILY_COST_LIMIT_USD', '3')
  const result = await checkCostCeiling(dbReturning([{ llm_cost_usd: 3 }]))
  assertEquals(result.withinBudget, false)
  Deno.env.delete('DAILY_COST_LIMIT_USD')
})

Deno.test('a metering failure allows generation rather than taking the product down', async () => {
  const result = await checkCostCeiling(dbReturning(null, { message: 'connection lost' }))
  assertEquals(result.withinBudget, true)
})

Deno.test('the message tells the reader what is still open', () => {
  assertEquals(COST_CEILING_MESSAGE.includes('Learning-path studies are still available'), true)
})
