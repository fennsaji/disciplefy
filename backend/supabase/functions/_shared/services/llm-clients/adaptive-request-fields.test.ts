// Run with: deno test model-request-fields.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { adaptiveRequestFields, THINKING_HEADROOM_TOKENS } from './anthropic-client.ts'
import { parseResultLine } from './anthropic-batch.ts'

/**
 * Sonnet 5.5 and Haiku 5.5 reject a non-default temperature or top_k with a
 * 400, and think before answering by default, so a request sized for Sonnet
 * 4.5 came back as a thinking block cut off at max_tokens with no text
 * (GitHub issue #417).
 */

Deno.test('requests send no sampling parameters and set low effort', () => {
  const fields = adaptiveRequestFields(500) as Record<string, unknown>
  assertEquals(fields.temperature, undefined)
  assertEquals(fields.top_k, undefined)
  assertEquals(fields.output_config, { effort: 'low' })
})

Deno.test('requests get thinking headroom on top of the reply budget', () => {
  assertEquals(adaptiveRequestFields(500).max_tokens, 500 + THINKING_HEADROOM_TOKENS)
})

Deno.test('batch results skip thinking blocks and keep only the text', () => {
  const line = JSON.stringify({
    custom_id: 'a',
    result: {
      type: 'succeeded',
      message: {
        stop_reason: 'end_turn',
        content: [{ type: 'thinking', thinking: '' }, { type: 'text', text: '{"ok":true}' }],
        usage: { input_tokens: 10, output_tokens: 5 },
      },
    },
  })
  assertEquals(parseResultLine(line).content, '{"ok":true}')
})

Deno.test('a refused batch result is an error, not empty content', () => {
  const line = JSON.stringify({
    custom_id: 'b',
    result: {
      type: 'succeeded',
      message: { stop_reason: 'refusal', stop_details: { type: 'refusal', category: 'general_harms' }, content: [], usage: {} },
    },
  })
  const result = parseResultLine(line)
  assertEquals(result.content, undefined)
  assertEquals(result.error, 'refusal: general_harms')
})
