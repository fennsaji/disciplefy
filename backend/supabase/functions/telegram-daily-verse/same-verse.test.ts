// The Telegram post must carry exactly the verse the app shows that day: both
// read the same daily_verses_cache row through DailyVerseService.getDailyVerse.
import { assert, assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { DailyVerseService, clearDailyVerseMemoryCache } from '../daily-verse/daily-verse-service.ts'
import { toDailyVerseResponseBody } from '../daily-verse/response.ts'
import { buildDailyVerseMessage, verseFor, type VerseLanguage } from './message.ts'

const row = {
  uuid: 'row-1',
  expires_at: '2999-01-01T00:00:00Z',
  verse_data: {
    reference: 'Philippians 4:13',
    referenceTranslations: { en: 'Philippians 4:13', hi: 'फिलिप्पियों 4:13', ml: 'ഫിലിപ്പിയർ 4:13' },
    translations: {
      esv: 'I can do all things through Christ which strengtheneth me.',
      hi: 'जो मुझे सामर्थ्य देता है उसमें मैं सब कुछ कर सकता हूँ।',
      ml: 'എന്നെ ശക്തനാക്കുന്നവൻ മുഖാന്തരം എനിക്ക് എല്ലാം ചെയ്യുവാൻ കഴിയും.',
    },
    date: '2026-10-01',
  },
}

const chain = { eq: () => chain, gt: () => chain, single: () => Promise.resolve({ data: structuredClone(row), error: null }) }
const fakeSupabase = { from: () => ({ select: () => chain }) }
const noLlm = () => Promise.reject(new Error('must not select a new verse'))

for (const lang of ['en', 'hi', 'ml'] as VerseLanguage[]) {
  Deno.test(`telegram ${lang} post uses the same reference and text as the daily-verse endpoint`, async () => {
    clearDailyVerseMemoryCache()
    const svc = new DailyVerseService(fakeSupabase, noLlm, () => Promise.reject(new Error('no fetch')))
    const endpointBody = toDailyVerseResponseBody(await svc.getDailyVerse('2026-10-01', lang))
    clearDailyVerseMemoryCache()
    const telegramVerse = await svc.getDailyVerse('2026-10-01', lang)

    const appText = lang === 'en' ? endpointBody.translations.esv : lang === 'hi' ? endpointBody.translations.hindi : endpointBody.translations.malayalam
    const picked = verseFor(telegramVerse, lang)!
    assertEquals(picked.text, appText)
    assertEquals(picked.reference, endpointBody.referenceTranslations[lang])
    assert(buildDailyVerseMessage(lang, picked.reference, picked.text).includes(appText!))
  })
}
