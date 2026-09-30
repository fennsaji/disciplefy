// Run with: deno test guide-fields.test.ts
import { assert, assertEquals, assertThrows } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { GUIDE_SUMMARY_MAX_LENGTH, parseGuideStudyMode, parseGuideSummary } from './guide-fields.ts'

Deno.test('parseGuideStudyMode accepts the app study modes and treats absence as null', () => {
  assertEquals(parseGuideStudyMode('standard'), 'standard')
  assertEquals(parseGuideStudyMode(' Deep '), 'deep')
  assertEquals(parseGuideStudyMode(undefined), null)
  assertEquals(parseGuideStudyMode(null), null)
  assertEquals(parseGuideStudyMode(''), null)
})

Deno.test('parseGuideStudyMode rejects unknown modes and non-strings', () => {
  assertThrows(() => parseGuideStudyMode('recommended'))
  assertThrows(() => parseGuideStudyMode('<script>'))
  assertThrows(() => parseGuideStudyMode(3))
})

Deno.test('parseGuideSummary returns trimmed plain text', () => {
  assertEquals(parseGuideSummary('  God works <b>all</b> things\n\ntogether.  '), 'God works ball/b things together.')
  assertEquals(parseGuideSummary('   '), null)
  assertEquals(parseGuideSummary(undefined), null)
  assertThrows(() => parseGuideSummary({ text: 'x' }))
})

Deno.test('parseGuideSummary caps the length on a word boundary', () => {
  const long = 'word '.repeat(200)
  const result = parseGuideSummary(long)!
  assert(result.length <= GUIDE_SUMMARY_MAX_LENGTH)
  assert(result.endsWith('…'))
  assert(!result.includes('  '))
})
