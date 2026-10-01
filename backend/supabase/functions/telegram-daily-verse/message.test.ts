// Run with: deno test message.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { buildDailyVerseMessage, DAILY_VERSE_URL, verseFor } from './message.ts'

const verse = {
  reference: 'Philippians 4:13',
  referenceTranslations: { en: 'Philippians 4:13', hi: 'फिलिप्पियों 4:13', ml: 'ഫിലിപ്പിയർ 4:13' },
  translations: { esv: 'I can do all things.', hi: 'मैं सब कुछ कर सकता हूँ।', ml: 'എനിക്കു സകലവും ചെയ്വാൻ കഴിയും.' },
}

Deno.test('english post cites KJV and links to the daily verse', () => {
  const v = verseFor(verse, 'en')!
  assertEquals(buildDailyVerseMessage('en', v.reference, v.text), [
    "🌅 Today's Verse", '', 'Philippians 4:13 (KJV)', '', 'I can do all things.', '', `📱 ${DAILY_VERSE_URL}`,
  ].join('\n'))
})

Deno.test('hindi and malayalam use localized reference and IRV', () => {
  const hi = verseFor(verse, 'hi')!
  assertEquals(buildDailyVerseMessage('hi', hi.reference, hi.text).includes('फिलिप्पियों 4:13 (IRV)'), true)
  const ml = verseFor(verse, 'ml')!
  assertEquals(ml.text, 'എനിക്കു സകലവും ചെയ്വാൻ കഴിയും.')
  assertEquals(buildDailyVerseMessage('ml', ml.reference, ml.text).includes('ഫിലിപ്പിയർ 4:13 (IRV)'), true)
})

Deno.test('legacy translation keys and missing reference translation fall back', () => {
  const v = verseFor({ reference: 'John 3:16', translations: { hindi: 'क्योंकि' } }, 'hi')!
  assertEquals(v, { reference: 'John 3:16', text: 'क्योंकि' })
})

Deno.test('missing text yields null instead of an empty post', () => {
  assertEquals(verseFor({ reference: 'John 3:16', translations: { esv: '  ' } }, 'en'), null)
})
