import { assert, assertEquals, assertFalse } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { DailyVerseService, TEXT_SOURCE, tidyVerseText, type VerseTextFetcher } from './daily-verse-service.ts'
import { LLMService } from '../_shared/services/llm-service.ts'
import { createVerseReferencePrompt } from '../_shared/services/llm-utils/prompt-builder.ts'

const BSB_PHIL_4_13 = 'I can do all things through Christ who gives me strength.'
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

Deno.test('LLM chooses only the reference; text is fetched from the Bible text service', async () => {
  const fetched: string[] = []
  const fetcher: VerseTextFetcher = (ref) => {
    fetched.push(ref)
    return Promise.resolve({ en: { text: `¶ ${BSB_PHIL_4_13}` }, hi: { text: '“हिंदी पाठ' }, ml: { text: 'മലയാളം' } })
  }
  const verse = await generate(new DailyVerseService(fakeSupabase, referenceOnlyLlm(), fetcher))
  assertEquals(fetched, ['Philippians 4:13'])
  assertEquals(verse.reference, 'Philippians 4:13')
  assertEquals(verse.translations, { esv: BSB_PHIL_4_13, hi: 'हिंदी पाठ', ml: 'മലയാളം' })
})

Deno.test('incomplete Bible text falls back to the BSB emergency verse', async () => {
  const fetcher: VerseTextFetcher = () =>
    Promise.resolve({ en: { text: 'x' }, hi: { text: '' }, ml: { text: 'y' } })
  const verse = await generate(new DailyVerseService(fakeSupabase, referenceOnlyLlm(), fetcher))
  assert(verse.translations.hi.length > 0)
  for (const p of ESV_PHRASES) assertFalse(verse.translations.esv.includes(p))
})

Deno.test('emergency fallbacks are BSB wording, never ESV', async () => {
  const failingLlm = () => Promise.reject(new Error('llm down'))
  const svc = new DailyVerseService(fakeSupabase, failingLlm, () => Promise.reject(new Error('unused')))
  // deno-lint-ignore no-explicit-any
  const all = (svc as any).EMERGENCY_FALLBACK_VERSES as Array<{ reference: string; translations: { esv: string; hi: string; ml: string } }>
  for (const v of all) {
    for (const p of ESV_PHRASES) assertFalse(v.translations.esv.includes(p), `${v.reference} has ESV wording`)
    assert(v.translations.hi && v.translations.ml)
  }
  assertEquals(all.find((v) => v.reference === 'Philippians 4:13')!.translations.esv, BSB_PHIL_4_13)
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

// --- getDailyVerse: existing rows keep their reference --------------------

import { clearDailyVerseMemoryCache } from './daily-verse-service.ts'

const ROW_UUID = '11111111-1111-1111-1111-111111111111'
const legacyRow = (overrides: Record<string, unknown> = {}) => ({
  uuid: ROW_UUID,
  verse_data: {
    reference: 'Romans 12:2',
    referenceTranslations: { en: 'Romans 12:2', hi: 'रोमियों 12:2', ml: 'റോമർ 12:2' },
    translations: { esv: 'LLM wording', hi: 'LLM हिंदी', ml: 'LLM മലയാളം' },
    date: '2026-10-01',
  },
  expires_at: new Date(Date.now() + 86_400_000).toISOString(),
  text_source: null,
  ...overrides,
})

/** Fake table: one optional row for the date; records updates and upserts. */
function tableFake(row: Record<string, unknown> | null, updateError: unknown = null) {
  const updates: Record<string, unknown>[] = []
  const upserts: Record<string, unknown>[] = []
  const chain = (result: unknown) => {
    const c: Record<string, unknown> = {}
    for (const m of ['eq', 'gte', 'order', 'select']) c[m] = () => c
    c.maybeSingle = () => Promise.resolve(result)
    c.single = () => Promise.resolve(result)
    c.then = (r: (v: unknown) => unknown) => Promise.resolve(result).then(r)
    return c
  }
  const supabase = {
    from: () => ({
      select: (cols: string) => cols === 'verse_data' ? chain({ data: [], error: null }) : chain({ data: row, error: null }),
      update: (u: Record<string, unknown>) => { updates.push(u); return chain({ error: updateError }) },
      upsert: (u: Record<string, unknown>) => { upserts.push(u); return chain({ data: { uuid: 'new-uuid' }, error: null }) },
    }),
  }
  return { supabase, updates, upserts }
}

const apiOn = () => Promise.resolve(true)
const bsbFetcher = (fetched: string[]): VerseTextFetcher => (ref) => {
  fetched.push(ref)
  return Promise.resolve({ en: { text: 'BSB text' }, hi: { text: 'IRV हिंदी' }, ml: { text: 'IRV മലയാളം' } })
}
const llmMustNotRun = () => Promise.reject(new Error('LLM must not pick a new reference for an existing row'))

Deno.test('legacy row is refreshed in place: same reference and id, new wording', async () => {
  clearDailyVerseMemoryCache()
  const fake = tableFake(legacyRow())
  const fetched: string[] = []
  const svc = new DailyVerseService(fake.supabase, llmMustNotRun, bsbFetcher(fetched), apiOn)
  const verse = await svc.getDailyVerse('2026-10-01')
  assertEquals(fetched, ['Romans 12:2'])
  assertEquals(verse.reference, 'Romans 12:2')
  assertEquals(verse.id, ROW_UUID)
  assertEquals(verse.translations, { esv: 'BSB text', hi: 'IRV हिंदी', ml: 'IRV മലയാളം' })
  assertEquals(fake.upserts.length, 0)
  assertEquals(fake.updates.length, 1)
  assertEquals(fake.updates[0].text_source, TEXT_SOURCE)
})

Deno.test('expired current-source row is refreshed, never re-picked', async () => {
  clearDailyVerseMemoryCache()
  const fake = tableFake(legacyRow({ text_source: TEXT_SOURCE, expires_at: new Date(Date.now() - 1000).toISOString() }))
  const fetched: string[] = []
  const verse = await new DailyVerseService(fake.supabase, llmMustNotRun, bsbFetcher(fetched), apiOn).getDailyVerse('2026-10-01')
  assertEquals(fetched, ['Romans 12:2'])
  assertEquals(verse.id, ROW_UUID)
})

Deno.test('fresh current-source row is served as-is without fetching', async () => {
  clearDailyVerseMemoryCache()
  const fake = tableFake(legacyRow({ text_source: TEXT_SOURCE }))
  const fetched: string[] = []
  const verse = await new DailyVerseService(fake.supabase, llmMustNotRun, bsbFetcher(fetched), apiOn).getDailyVerse('2026-10-01')
  assertEquals(fetched, [])
  assertEquals(fake.updates.length, 0)
  assertEquals(verse.translations.esv, 'LLM wording')
})

Deno.test('refresh failure keeps serving the existing row and retries on the next read', async () => {
  clearDailyVerseMemoryCache()
  const fake = tableFake(legacyRow())
  let calls = 0
  const failing: VerseTextFetcher = () => { calls++; return Promise.reject(new Error('Bible text down')) }
  const svc = new DailyVerseService(fake.supabase, llmMustNotRun, failing, apiOn)
  const first = await svc.getDailyVerse('2026-10-01')
  assertEquals(first.reference, 'Romans 12:2')
  assertEquals(first.id, ROW_UUID)
  assertEquals(first.translations.esv, 'LLM wording')
  assertEquals(fake.updates.length, 0)
  await svc.getDailyVerse('2026-10-01')
  assertEquals(calls, 2)
})

Deno.test('no row for the date: LLM picks a new reference and the row is marked with the current text source', async () => {
  clearDailyVerseMemoryCache()
  const fake = tableFake(null)
  const fetched: string[] = []
  const verse = await new DailyVerseService(fake.supabase, referenceOnlyLlm(), bsbFetcher(fetched), apiOn).getDailyVerse('2026-10-02')
  assertEquals(verse.reference, 'Philippians 4:13')
  assertEquals(verse.id, 'new-uuid')
  assertEquals(fake.upserts.length, 1)
  assertEquals(fake.upserts[0].text_source, TEXT_SOURCE)
})

Deno.test('KJV row from API.Bible (text_source bible_api) is refreshed in place with the same reference', async () => {
  clearDailyVerseMemoryCache()
  const fake = tableFake(legacyRow({ text_source: 'bible_api' }))
  const fetched: string[] = []
  const verse = await new DailyVerseService(fake.supabase, llmMustNotRun, bsbFetcher(fetched), apiOn).getDailyVerse('2026-10-01')
  assertEquals(fetched, ['Romans 12:2'])
  assertEquals(verse.reference, 'Romans 12:2')
  assertEquals(verse.id, ROW_UUID)
  assertEquals(verse.translations.esv, 'BSB text')
  assertEquals(fake.updates[0].text_source, TEXT_SOURCE)
})
