// Run with: deno test --allow-env verse-lookup.test.ts
import { assertEquals, assertRejects } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { lookupVerses, VerseLookupError } from './verse-lookup.ts'

type Call = { url: URL }

function fakeFetch(calls: Call[], respond: (url: URL) => { status: number; body: unknown }) {
  return (input: string) => {
    const url = new URL(input)
    calls.push({ url })
    const r = respond(url)
    return Promise.resolve(new Response(JSON.stringify(r.body), { status: r.status }))
  }
}

const ok = (verses: { chapter: number; verse: number; text: string }[], reference = 'x') => ({
  status: 200,
  body: { success: true, data: { book: 'JHN', book_name: 'John', reference, verses, text: verses.map(v => v.text).join(' '), attribution: 'attr' } },
})

Deno.test('single verse: English defaults to BSB, response shape unchanged', async () => {
  const calls: Call[] = []
  const data = await lookupVerses(
    { book: 'John', chapter: 3, verse_start: 16, language: 'en' }, null,
    fakeFetch(calls, () => ok([{ chapter: 3, verse: 16, text: 'For God so loved' }])),
  )
  assertEquals(calls[0].url.pathname, '/api/v1/bible/bsb/verses')
  assertEquals(calls[0].url.searchParams.get('book'), 'JHN')
  assertEquals(calls[0].url.searchParams.get('verse_start'), '16')
  assertEquals(calls[0].url.searchParams.has('verse_end'), false)
  assertEquals(data.reference, 'John 3:16')
  assertEquals(data.localizedReference, 'John 3:16')
  assertEquals(data.text, 'For God so loved')
  assertEquals(data.verses, undefined)
  assertEquals(data.translation, 'Berean Standard Bible (BSB)')
  assertEquals(data.translationAbbreviation, 'BSB')
})

Deno.test('KJV can be requested; a version of another language is ignored', async () => {
  const calls: Call[] = []
  const f = fakeFetch(calls, () => ok([{ chapter: 3, verse: 16, text: 't' }]))
  await lookupVerses({ book: 'John', chapter: 3, verse_start: 16, language: 'en', version: 'kjv' }, null, f)
  await lookupVerses({ book: 'John', chapter: 3, verse_start: 16, language: 'en', version: 'irv-ml' }, null, f)
  await lookupVerses({ book: 'യോഹന്നാൻ', chapter: 3, verse_start: 16, language: 'ml', version: 'sv-ml' }, null, f)
  await lookupVerses({ book: 'यूहन्ना', chapter: 3, verse_start: 16, language: 'hi' }, null, f)
  assertEquals(calls.map(c => c.url.pathname.split('/')[4]), ['kjv', 'bsb', 'sv-ml', 'irv-hi'])
})

Deno.test('range returns per-verse items; whole chapter omits verse params', async () => {
  const calls: Call[] = []
  const f = fakeFetch(calls, () => ok([{ chapter: 3, verse: 16, text: 'a' }, { chapter: 3, verse: 17, text: 'b' }]))
  const range = await lookupVerses({ book: 'John', chapter: 3, verse_start: 16, verse_end: 17, language: 'hi' }, null, f)
  assertEquals(calls[0].url.searchParams.get('verse_end'), '17')
  assertEquals(range.verses, [{ number: 16, text: 'a' }, { number: 17, text: 'b' }])
  assertEquals(range.localizedReference, 'यूहन्ना 3:16-17')

  const chapter = await lookupVerses({ book: 'John', chapter: 3, verse_start: 1, verse_end: 999, language: 'en' }, null, f)
  assertEquals(calls[1].url.searchParams.has('verse_start'), false)
  assertEquals(chapter.reference, 'John 3')
  assertEquals(chapter.verses, undefined)
})

Deno.test('cross-chapter passage passes end_chapter and tags chapters', async () => {
  const calls: Call[] = []
  const data = await lookupVerses(
    { book: '1 Corinthians', chapter: 10, verse_start: 33, verse_end: 1, language: 'en' },
    { chapter: 10, verseStart: 33, endChapter: 11, verseEnd: 1 },
    fakeFetch(calls, () => ok([{ chapter: 10, verse: 33, text: 'a' }, { chapter: 11, verse: 1, text: 'b' }])),
  )
  assertEquals(calls[0].url.searchParams.get('end_chapter'), '11')
  assertEquals(calls[0].url.searchParams.get('verse_end'), '1')
  assertEquals(data.reference, '1 Corinthians 10:33-11:1')
  assertEquals(data.verses, [{ number: 33, text: 'a', chapter: 10 }, { number: 1, text: 'b', chapter: 11 }])
})

Deno.test('404 from the text service becomes NOT_FOUND; unknown book is a validation error', async () => {
  const f = fakeFetch([], () => ({ status: 404, body: { success: false, error: { code: 'NOT_FOUND', message: 'nope' } } }))
  const e = await assertRejects(() => lookupVerses({ book: 'John', chapter: 30, verse_start: 1, language: 'en' }, null, f), VerseLookupError)
  assertEquals(e.status, 404)
  const v = await assertRejects(() => lookupVerses({ book: 'Hezekiah', chapter: 1, verse_start: 1, language: 'en' }, null, f), VerseLookupError)
  assertEquals(v.status, 400)
})
