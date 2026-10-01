// Run with: deno test --allow-env bible-text-service.test.ts
import { assertEquals, assertRejects } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  BibleTextNotFoundError,
  buildPassageUrl,
  fetchPassage,
  fetchVerseAllLanguages,
  parseReference,
  resolveVersion,
} from './bible-text-service.ts'

const passageBody = (text: string) => ({
  success: true,
  data: { book: 'JHN', book_name: 'John', reference: 'John 3:16', verses: [{ chapter: 3, verse: 16, text }], text, attribution: 'a' },
})

Deno.test('parseReference handles single verses, ranges, cross-chapter and aliases', () => {
  assertEquals(parseReference('John 3:16'), { book: 'JHN', chapter: 3, verseStart: 16, verseEnd: 16 })
  assertEquals(parseReference('Psalm 23:1-3'), { book: 'PSA', chapter: 23, verseStart: 1, verseEnd: 3 })
  assertEquals(parseReference('1 Corinthians 10:23-11:1'), { book: '1CO', chapter: 10, verseStart: 23, verseEnd: 1, endChapter: 11 })
  assertEquals(parseReference('song of songs 2:4').book, 'SNG')
})

Deno.test('resolveVersion defaults per language and only honours same-language versions', () => {
  assertEquals(resolveVersion('en').id, 'bsb')
  assertEquals(resolveVersion('en', 'KJV').id, 'kjv')
  assertEquals(resolveVersion('en', 'irv-hi').id, 'bsb')
  assertEquals(resolveVersion('ml').id, 'irv-ml')
  assertEquals(resolveVersion('ml', 'sv-ml').id, 'sv-ml')
  assertEquals(resolveVersion('hi', '../x').id, 'irv-hi')
})

Deno.test('buildPassageUrl encodes params and skips same end_chapter', () => {
  const url = new URL(buildPassageUrl('http://h:1', 'irv-ml', { book: 'JHN', chapter: 3, verseStart: 16, endChapter: 3 }))
  assertEquals(url.pathname, '/api/v1/bible/irv-ml/verses')
  assertEquals(url.searchParams.has('end_chapter'), false)
})

Deno.test('fetchPassage uses BIBLE_TEXT_URL and retries 5xx', async () => {
  Deno.env.set('BIBLE_TEXT_URL', 'http://bible.test/')
  const urls: string[] = []
  let n = 0
  const f = (u: string) => {
    urls.push(u)
    n++
    return Promise.resolve(n === 1
      ? new Response('busy', { status: 503 })
      : new Response(JSON.stringify(passageBody('For God')), { status: 200 }))
  }
  const p = await fetchPassage('bsb', { book: 'JHN', chapter: 3, verseStart: 16 }, f)
  assertEquals(p.text, 'For God')
  assertEquals(n, 2)
  assertEquals(urls[0].startsWith('http://bible.test/api/v1/bible/bsb/verses?'), true)
})

Deno.test('fetchPassage: 404 is BibleTextNotFoundError without retry', async () => {
  let n = 0
  const f = () => { n++; return Promise.resolve(new Response('{}', { status: 404 })) }
  await assertRejects(() => fetchPassage('kjv', { book: 'JHN', chapter: 99 }, f), BibleTextNotFoundError)
  assertEquals(n, 1)
})

Deno.test('fetchVerseAllLanguages: English required, other languages fall back to empty', async () => {
  const f = (u: string) => Promise.resolve(u.includes('/irv-hi/')
    ? new Response('{}', { status: 500 })
    : new Response(JSON.stringify(passageBody(u.includes('/bsb/') ? 'en' : 'ml')), { status: 200 }))
  const all = await fetchVerseAllLanguages('John 3:16', f)
  assertEquals([all.en.text, all.hi.text, all.ml.text], ['en', '', 'ml'])
  assertEquals(all.en.translation, 'Berean Standard Bible (BSB)')
})
