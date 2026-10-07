import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { detectScriptLanguage, parseStudyLanguage, resolveTopicLanguage } from './content-language.ts'

Deno.test('detects Hindi and Malayalam scripts', () => {
  assertEquals(detectScriptLanguage('आत्मिक युद्ध'), 'hi')
  assertEquals(detectScriptLanguage('ആത്മീയ യുദ്ധം'), 'ml')
  assertEquals(detectScriptLanguage('Spiritual Warfare'), null)
})

Deno.test('Hindi topic title sent with en resolves to hi', () => {
  assertEquals(resolveTopicLanguage('en', 'आत्मिक युद्ध', 'topic-1'), 'hi')
})

Deno.test('Malayalam topic title sent with en resolves to ml', () => {
  assertEquals(resolveTopicLanguage('en', 'ആത്മീയ യുദ്ധം', 'topic-1'), 'ml')
})

Deno.test('matching or Latin titles keep the requested language', () => {
  assertEquals(resolveTopicLanguage('hi', 'आत्मिक युद्ध', 'topic-1'), 'hi')
  assertEquals(resolveTopicLanguage('hi', 'Spiritual Warfare', 'topic-1'), 'hi')
  assertEquals(resolveTopicLanguage('en', 'Spiritual Warfare', 'topic-1'), 'en')
})

Deno.test('non-topic (Generate tab) requests are never overridden', () => {
  assertEquals(resolveTopicLanguage('en', 'आत्मिक युद्ध'), 'en')
})

Deno.test('parseStudyLanguage accepts the three supported languages', () => {
  assertEquals(parseStudyLanguage('en'), 'en')
  assertEquals(parseStudyLanguage('hi'), 'hi')
  assertEquals(parseStudyLanguage('ml'), 'ml')
})

Deno.test('parseStudyLanguage defaults a missing language to en', () => {
  assertEquals(parseStudyLanguage(null), 'en')
})

Deno.test('parseStudyLanguage rejects anything else', () => {
  assertEquals(parseStudyLanguage('en1'), null)
  assertEquals(parseStudyLanguage(''), null)
  assertEquals(parseStudyLanguage('EN'), null)
  assertEquals(parseStudyLanguage('en-US'), null)
  assertEquals(parseStudyLanguage(' en'), null)
  assertEquals(parseStudyLanguage('fr'), null)
  assertEquals(parseStudyLanguage('e'.repeat(5000)), null)
})
