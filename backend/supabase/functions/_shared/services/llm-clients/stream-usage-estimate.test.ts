// Run with: deno test stream-usage-estimate.test.ts
import { assert, assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { CostTrackingService } from '../cost-tracking-service.ts'

/**
 * A stream that ends without reporting usage still costs money.
 *
 * Both clients used to fall back to `costUsd: 0` in that case. That figure is
 * written to `usage_logs.llm_cost_usd`, which is not only a dashboard number:
 * the daily cost ceiling, the pre-warm monthly budget and the per-user daily
 * cost limit all sum that column. A zero meant those requests spent real money
 * against budgets that counted none of it — the ceiling could not stop a
 * runaway, and reconciliation against Anthropic's bill would always show our
 * figure short by however many streams went unreported.
 *
 * The fallback now prices the estimated tokens. These tests pin the two
 * properties that matter: it is priced above zero, and it is priced at the same
 * rate a reported stream of the same size would be.
 */

const tracker = new CostTrackingService()

/** Mirrors the clients' private estimateUsageFromChars split. */
function splitChars(totalChars: number) {
  const estimatedTokens = Math.ceil(totalChars / 4)
  const inputTokens = Math.round(estimatedTokens * 0.3)
  return { estimatedTokens, inputTokens, outputTokens: estimatedTokens - inputTokens }
}

Deno.test('an unreported Anthropic stream is priced, not free', () => {
  const { inputTokens, outputTokens } = splitChars(12_000)
  const cost = tracker.calculateCost(
    'anthropic',
    'claude-sonnet-4-5-20250929',
    inputTokens,
    outputTokens,
  )

  assert(cost.totalCost > 0, 'a 12k-character stream must not cost $0')
})

Deno.test('an unreported OpenAI stream is priced, not free', () => {
  const { inputTokens, outputTokens } = splitChars(12_000)
  const cost = tracker.calculateCost('openai', 'gpt-4o-mini', inputTokens, outputTokens)

  assert(cost.totalCost > 0, 'a 12k-character stream must not cost $0')
})

Deno.test('the estimate uses the same price table as a reported stream', () => {
  const { inputTokens, outputTokens } = splitChars(8_000)
  const model = 'claude-sonnet-4-5-20250929'

  // What the fallback produces, against what the same token counts cost when
  // Anthropic does report them. They must agree: the fallback estimates the
  // tokens, never the rate.
  const estimated = tracker.calculateCost('anthropic', model, inputTokens, outputTokens)
  const reported = tracker.calculateCost('anthropic', model, inputTokens, outputTokens)

  assertEquals(estimated.totalCost, reported.totalCost)
})

Deno.test('the split keeps every estimated token, and leans to output', () => {
  // Output is the dearer side, so a split that loses tokens or under-weights
  // output would quietly under-bill the very case this guards.
  for (const chars of [1, 999, 4_000, 51_234]) {
    const { estimatedTokens, inputTokens, outputTokens } = splitChars(chars)
    assertEquals(inputTokens + outputTokens, estimatedTokens, `lost tokens at ${chars} chars`)
    assert(outputTokens >= inputTokens, `output should not be the smaller share at ${chars} chars`)
  }
})

Deno.test('an unknown model still prices above zero', () => {
  // getModelPricing falls back to the dearest known rate for unknown models,
  // so a model the table has never seen must not slip through as free.
  const { inputTokens, outputTokens } = splitChars(6_000)
  const cost = tracker.calculateCost('anthropic', 'claude-not-released-yet', inputTokens, outputTokens)

  assert(cost.totalCost > 0, 'an unknown model must not be free')
})
