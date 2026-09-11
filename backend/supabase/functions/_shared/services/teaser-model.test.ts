import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { teaserModelForLanguage } from './llm-service.ts'

Deno.test('teaser model: Hindi and Malayalam on Sonnet, English on Haiku', () => {
  assertEquals(teaserModelForLanguage('hi'), 'claude-sonnet-4-5-20250929')
  assertEquals(teaserModelForLanguage('ml'), 'claude-sonnet-4-5-20250929')
  assertEquals(teaserModelForLanguage('en'), 'claude-haiku-4-5-20251001')
  assertEquals(teaserModelForLanguage('xx'), 'claude-haiku-4-5-20251001')
})
