import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { MODE_SECTIONS, expectedSectionTotal } from './mode-sections.ts'
import { StreamingJsonParser } from './streaming-json-parser.ts'
import { createStudyGuidePrompt } from './llm-utils/prompt-builder.ts'
import { getLanguageConfigOrDefault } from './llm-config/language-configs.ts'
import type { StudyMode } from './llm-types.ts'
import parityTable from './mode-sections.json' with { type: 'json' }

const MODES: StudyMode[] = ['quick', 'standard', 'deep', 'lectio', 'sermon']

/** Top-level keys of the JSON schema in [mode]'s prompt, in the order asked for. */
function promptSchemaKeys(mode: StudyMode): string[] {
  const prompt = createStudyGuidePrompt(
    { inputType: 'topic', inputValue: 'Grace', language: 'en', studyMode: mode },
    getLanguageConfigOrDefault('en'),
  )
  return [...prompt.userMessage.matchAll(/^ {2}"(\w+)":/gm)].map((m) => m[1])
}

Deno.test('every mode lists the keys its prompt schema asks for', () => {
  for (const mode of MODES) {
    assertEquals([...MODE_SECTIONS[mode]], promptSchemaKeys(mode), mode)
  }
})

Deno.test('no mode streams interpretation parts as their own sections', () => {
  for (const mode of MODES) {
    for (const part of ['interpretationPart1', 'interpretationPart2', 'interpretationPart3', 'interpretationPart4']) {
      assertEquals(MODE_SECTIONS[mode].includes(part as never), false, `${mode} ${part}`)
    }
  }
})

Deno.test('the total per mode is its key count, and the parser reports it', () => {
  for (const mode of MODES) {
    assertEquals(expectedSectionTotal(mode), MODE_SECTIONS[mode].length, mode)
    assertEquals(new StreamingJsonParser(mode).getTotalSections(), expectedSectionTotal(mode), mode)
  }
  assertEquals(expectedSectionTotal('quick'), 7)
})

Deno.test('MODE_SECTIONS matches the shared parity table the Flutter app also asserts', () => {
  const table = parityTable as Record<string, unknown>
  for (const mode of MODES) {
    assertEquals([...MODE_SECTIONS[mode]], table[mode], mode)
  }
  assertEquals(Object.keys(table).filter((k) => !k.startsWith('_')).sort(), [...MODES].sort())
})
