/**
 * Sections each study mode streams to the client, in the order its prompt's
 * JSON schema asks for them.
 *
 * Multi-pass modes generate interpretationPart1-4 but combine them into one
 * `interpretation` event before sending, so the parts are not listed here.
 *
 * Kept in step with the Flutter app's `expectedSectionKeysFor` through the
 * shared parity table `mode-sections.json`, which tests on both sides assert.
 * Every mode currently streams the same seven keys; the per-mode table lets a
 * mode differ later without touching the parser.
 */
import type { StudyMode } from './llm-types.ts'
import type { SectionType } from './streaming-json-parser.ts'

const SEVEN_SECTIONS: readonly SectionType[] = [
  'summary',
  'context',
  'passage',
  'interpretation',
  'relatedVerses',
  'reflectionQuestions',
  'prayerPoints',
]

export const MODE_SECTIONS: Readonly<Record<StudyMode, readonly SectionType[]>> = {
  quick: SEVEN_SECTIONS,
  standard: SEVEN_SECTIONS,
  deep: SEVEN_SECTIONS,
  lectio: SEVEN_SECTIONS,
  sermon: SEVEN_SECTIONS,
}

/** Number of section events a stream in [mode] sends. */
export function expectedSectionTotal(mode: StudyMode): number {
  return MODE_SECTIONS[mode].length
}
