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

Deno.test('an unpriced model is charged at the highest known rate, not zero', () => {
  const { totalCost } = service.calculateCost('anthropic', 'claude-something-unreleased', 1000, 1000)
  assertAlmostEquals(totalCost, 0.018, 1e-9)
  assertEquals(totalCost > 0, true)
})

Deno.test('Haiku 4.5 is priced at $1 and $5 per million', () => {
  const { totalCost } = service.calculateCost('anthropic', 'claude-haiku-4-5-20251001', 1_000_000, 0)
  assertAlmostEquals(totalCost, 1, 1e-9)
  const out = service.calculateCost('anthropic', 'claude-haiku-4-5-20251001', 0, 1_000_000)
  assertAlmostEquals(out.totalCost, 5, 1e-9)
})
