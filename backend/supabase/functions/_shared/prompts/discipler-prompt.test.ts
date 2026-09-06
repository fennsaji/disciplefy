// backend/supabase/functions/_shared/prompts/discipler-prompt.test.ts
// Run with: deno test discipler-prompt.test.ts
import { assertEquals, assertThrows } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildDisciplerSystemPrompt, buildDisciplerUserMessage, parseDisciplerOutput } from './discipler-prompt.ts'

Deno.test('system prompt carries the theological foundation and language rule', () => {
  const p = buildDisciplerSystemPrompt()
  assertEquals(p.includes('Sola'), true)
  assertEquals(p.includes('Hinglish'), true)
  assertEquals(p.includes('"action"'), true)
})

Deno.test('user message includes context, thread and asker', () => {
  const m = buildDisciplerUserMessage({
    trigger: 'question', fellowshipLanguage: 'hi', question: 'Kya fasting zaroori hai?',
    askerName: 'Rahul', guideContext: 'Fasting summary…',
    thread: [{ author: 'Anna', isMentor: true, content: 'Good question' }],
  })
  assertEquals(m.includes('Fellowship language: hi'), true)
  assertEquals(m.includes('Rahul'), true)
  assertEquals(m.includes('[mentor] Anna: Good question'), true)
  assertEquals(m.includes('Fasting summary…'), true)
})

Deno.test('parse accepts a fenced valid reply and normalises nulls', () => {
  const raw = '```json\n{"action":"reply","reaction":null,"language":"hinglish","reply":"Daniel 6:10","guide_request":null}\n```'
  assertEquals(parseDisciplerOutput(raw, 'question'), {
    action: 'reply', reaction: null, language: 'hinglish', reply: 'Daniel 6:10', guide_request: null,
  })
})

Deno.test('parse forces reply on mention and rejects bad shapes', () => {
  const react = '{"action":"react","reaction":"heart","language":"en","reply":null,"guide_request":null}'
  assertEquals(parseDisciplerOutput(react, 'question').action, 'react')
  assertThrows(() => parseDisciplerOutput(react, 'mention'))
  assertThrows(() => parseDisciplerOutput('{"action":"react","reaction":"i_prayed","language":"en","reply":null,"guide_request":null}', 'question'))
  assertThrows(() => parseDisciplerOutput('{"action":"reply","reaction":null,"language":"fr","reply":"x","guide_request":null}', 'question'))
  assertThrows(() => parseDisciplerOutput('{"action":"reply","reaction":null,"language":"en","reply":"","guide_request":null}', 'question'))
  assertThrows(() => parseDisciplerOutput('not json', 'question'))
})

Deno.test('parse validates guide_request', () => {
  const ok = '{"action":"reply","reaction":null,"language":"en","reply":"x","guide_request":{"input_type":"scripture","input_value":"John 15"}}'
  assertEquals(parseDisciplerOutput(ok, 'mention').guide_request, { input_type: 'scripture', input_value: 'John 15' })
  assertThrows(() => parseDisciplerOutput('{"action":"reply","reaction":null,"language":"en","reply":"x","guide_request":{"input_type":"video","input_value":"x"}}', 'mention'))
})
