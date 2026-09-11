import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { parseResultLine } from './anthropic-batch.ts'

Deno.test('batch result: a succeeded request yields its text and token counts', () => {
  const line = JSON.stringify({
    custom_id: 'topic-1:hi:standard:pass1',
    result: {
      type: 'succeeded',
      message: {
        content: [{ type: 'text', text: '{"summary":' }, { type: 'text', text: '"..."}' }],
        usage: { input_tokens: 100, cache_read_input_tokens: 900, output_tokens: 250 },
      },
    },
  })

  const parsed = parseResultLine(line)

  assertEquals(parsed.customId, 'topic-1:hi:standard:pass1')
  assertEquals(parsed.content, '{"summary":"..."}')
  assertEquals(parsed.inputTokens, 1000)
  assertEquals(parsed.outputTokens, 250)
  assertEquals(parsed.error, undefined)
})

Deno.test('batch result: a failed request keeps its id so the caller can retry it', () => {
  const line = JSON.stringify({
    custom_id: 'topic-2:ml:standard:pass1',
    result: { type: 'errored', error: { message: 'overloaded_error' } },
  })

  const parsed = parseResultLine(line)

  assertEquals(parsed.customId, 'topic-2:ml:standard:pass1')
  assertEquals(parsed.error, 'overloaded_error')
  assertEquals(parsed.content, undefined)
})

Deno.test('batch result: an expired request reports its type rather than throwing', () => {
  const parsed = parseResultLine(JSON.stringify({
    custom_id: 'topic-3:en:standard:pass2',
    result: { type: 'expired' },
  }))

  assertEquals(parsed.customId, 'topic-3:en:standard:pass2')
  assertEquals(parsed.error, 'expired')
})
