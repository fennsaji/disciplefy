import { assertAlmostEquals, assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { CostTrackingService } from './cost-tracking-service.ts'

const service = new CostTrackingService()
const SONNET = 'claude-sonnet-4-5-20250929'

Deno.test('plain call: input and output priced at the model rate', () => {
  const { totalCost } = service.calculateCost('anthropic', SONNET, 1000, 1000)
  // $0.003 in + $0.015 out
  assertAlmostEquals(totalCost, 0.018, 1e-9)
})

Deno.test('a cache read is charged at 10% of the input rate, not refunded', () => {
  const { totalCost } = service.calculateCost('anthropic', SONNET, 1000, 0, {
    cacheReadTokens: 10_000,
  })
  // 1,000 uncached + 10,000 read at 10% = 2,000 billable input tokens
  assertAlmostEquals(totalCost, 0.006, 1e-9)
})

Deno.test('a cache write is charged at 125% of the input rate', () => {
  const { totalCost } = service.calculateCost('anthropic', SONNET, 0, 0, {
    cacheCreationTokens: 1000,
  })
  assertAlmostEquals(totalCost, 0.00375, 1e-9)
})

Deno.test('a cache-heavy call can never cost less than nothing', () => {
  // The previous arithmetic subtracted 90% of the read tokens from a bill that
  // never included them, which drove heavily cached calls negative.
  const { totalCost } = service.calculateCost('anthropic', SONNET, 100, 100, {
    cacheReadTokens: 50_000,
  })
  assertEquals(totalCost > 0, true)
})

Deno.test('an unpriced model is charged above every model we run, not zero', () => {
  // Opus-class rates ($5/$25 per million). The fallback must stay dearer than
  // anything actually in the table, or switching to an untracked model
  // under-counts spend — which is the failure this fallback exists to prevent.
  const { totalCost } = service.calculateCost('anthropic', 'claude-something-unreleased', 1000, 1000)
  assertAlmostEquals(totalCost, 0.03, 1e-9)
  assertEquals(totalCost > 0, true)

  // Dearer than the priciest priced model, whatever that currently is.
  const sonnet = service.calculateCost('anthropic', SONNET, 1000, 1000).totalCost
  assertEquals(totalCost > sonnet, true)
})

Deno.test('gpt-4.1-mini is not priced like gpt-4o-mini', () => {
  // The table assumed they matched; 4.1-mini is $0.40/$1.60 per million against
  // 4o-mini's $0.15/$0.60, so every premium-English generation was logged at
  // roughly a third of its real cost.
  const mini41 = service.calculateCost('openai', 'gpt-4.1-mini-2025-04-14', 1_000_000, 0).totalCost
  const mini4o = service.calculateCost('openai', 'gpt-4o-mini-2024-07-18', 1_000_000, 0).totalCost

  assertAlmostEquals(mini41, 0.4, 1e-9)
  assertAlmostEquals(mini4o, 0.15, 1e-9)
  assertEquals(mini41 > mini4o, true)
})

Deno.test('gpt-3.5-turbo is priced at $0.50 and $1.50 per million', () => {
  assertAlmostEquals(service.calculateCost('openai', 'gpt-3.5-turbo', 1_000_000, 0).totalCost, 0.5, 1e-9)
  assertAlmostEquals(service.calculateCost('openai', 'gpt-3.5-turbo', 0, 1_000_000).totalCost, 1.5, 1e-9)
})

Deno.test('Sonnet 4.5 is priced at $3 and $15 per million', () => {
  assertAlmostEquals(service.calculateCost('anthropic', SONNET, 1_000_000, 0).totalCost, 3, 1e-9)
  assertAlmostEquals(service.calculateCost('anthropic', SONNET, 0, 1_000_000).totalCost, 15, 1e-9)
})

Deno.test('Haiku 4.5 is priced at $1 and $5 per million', () => {
  const { totalCost } = service.calculateCost('anthropic', 'claude-haiku-4-5-20251001', 1_000_000, 0)
  assertAlmostEquals(totalCost, 1, 1e-9)
  const out = service.calculateCost('anthropic', 'claude-haiku-4-5-20251001', 0, 1_000_000)
  assertAlmostEquals(out.totalCost, 5, 1e-9)
})
