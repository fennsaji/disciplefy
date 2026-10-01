import { assert, assertEquals, assertFalse } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { DailyVerseService, tidyVerseText, type VerseTextFetcher } from './daily-verse-service.ts'
import { LLMService } from '../_shared/services/llm-service.ts'
import { createVerseReferencePrompt } from '../_shared/services/llm-utils/prompt-builder.ts'

const KJV_PHIL_4_13 = 'I can do all things through Christ which strengtheneth me.'
const ESV_PHRASES = ['through him who strengthens me', 'whoever believes in him', 'his only Son,']

// Recent-verses query used for exclusions: returns no rows.
const fakeSupabase = {
  from: () => ({
    select: () => ({ gte: () => ({ eq: () => ({ order: () => Promise.resolve({ data: [], error: null }) }) }) }),
  }),
}

const referenceOnlyLlm = (reference = 'Philippians 4:13') => () =>
  Promise.resolve({
    generateDailyVerse: () =>
      Promise.resolve({ reference, referenceTranslations: { en: reference, hi: 'फिलिप्पियों 4:13', ml: 'ഫിലിപ്പിയർ 4:13' } }),
  } as unknown as LLMService)

// deno-lint-ignore no-explicit-any
const generate = (svc: DailyVerseService, date = new Date('2026-10-01')): Promise<any> =>
  // deno-lint-ignore no-explicit-any
  (svc as any).generateDailyVerse(date, 'en')

Deno.test('LLM chooses only the reference; text is fetched from the Bible API', async () => {
  const fetched: string[] = []
  const fetcher: VerseTextFetcher = (ref) => {
    fetched.push(ref)
    return Promise.resolve({ en: { text: `¶ ${KJV_PHIL_4_13}` }, hi: { text: '“हिंदी पाठ' }, ml: { text: 'മലയാളം' } })
  }
  const verse = await generate(new DailyVerseService(fakeSupabase, referenceOnlyLlm(), fetcher))
  assertEquals(fetched, ['Philippians 4:13'])
  assertEquals(verse.reference, 'Philippians 4:13')
  assertEquals(verse.translations, { esv: KJV_PHIL_4_13, hi: 'हिंदी पाठ', ml: 'മലയാളം' })
})

Deno.test('incomplete Bible API text falls back to the KJV emergency verse', async () => {
  const fetcher: VerseTextFetcher = () =>
    Promise.resolve({ en: { text: 'x' }, hi: { text: '' }, ml: { text: 'y' } })
  const verse = await generate(new DailyVerseService(fakeSupabase, referenceOnlyLlm(), fetcher))
  assert(verse.translations.hi.length > 0)
  for (const p of ESV_PHRASES) assertFalse(verse.translations.esv.includes(p))
})

Deno.test('emergency fallbacks are KJV wording, never ESV', async () => {
  const failingLlm = () => Promise.reject(new Error('llm down'))
  const svc = new DailyVerseService(fakeSupabase, failingLlm, () => Promise.reject(new Error('unused')))
  // deno-lint-ignore no-explicit-any
  const all = (svc as any).EMERGENCY_FALLBACK_VERSES as Array<{ reference: string; translations: { esv: string; hi: string; ml: string } }>
  for (const v of all) {
    for (const p of ESV_PHRASES) assertFalse(v.translations.esv.includes(p), `${v.reference} has ESV wording`)
    assert(v.translations.hi && v.translations.ml)
  }
  assertEquals(all.find((v) => v.reference === 'Philippians 4:13')!.translations.esv, KJV_PHIL_4_13)
  const verse = await generate(svc)
  assert(all.some((v) => v.translations.esv === verse.translations.esv))
})

Deno.test('mock LLM path returns a reference with no verse wording', () => {
  // deno-lint-ignore no-explicit-any
  const mock = (LLMService.prototype as any).getMockDailyVerse.call({}, ['John 3:16'])
  assertEquals(Object.keys(mock).sort(), ['reference', 'referenceTranslations'])
  assert(mock.reference !== 'John 3:16')
})

Deno.test('verse prompt asks for the reference only', () => {
  const { systemMessage } = createVerseReferencePrompt([], 'en')
  assert(systemMessage.includes('Return ONLY the reference'))
  assertFalse(/"translations"\s*:/.test(systemMessage))
})

Deno.test('tidyVerseText strips paragraph marks and unbalanced quotes', () => {
  assertEquals(tidyVerseText('¶ For God so loved'), 'For God so loved')
  assertEquals(tidyVerseText('रहेगा।”'), 'रहेगा।')
  assertEquals(tidyVerseText('“a” b'), '“a” b')
})
