import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { teaserModelForLanguage } from './llm-service.ts'

Deno.test('teaser model: Hindi and Malayalam on Sonnet, English on Haiku', () => {
  assertEquals(teaserModelForLanguage('hi'), 'claude-sonnet-5-5')
  assertEquals(teaserModelForLanguage('ml'), 'claude-sonnet-5-5')
  assertEquals(teaserModelForLanguage('en'), 'claude-haiku-5-5')
  assertEquals(teaserModelForLanguage('xx'), 'claude-haiku-5-5')
})
