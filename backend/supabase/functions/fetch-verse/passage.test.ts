// Run with: deno test passage.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import {
  buildPassageId,
  buildPassageUrl,
  formatCrossChapterReference,
  parseCrossChapterRange,
  splitNumberedVerses,
} from './passage.ts'

const range = { chapter: 10, verseStart: 23, endChapter: 11, verseEnd: 1 }

Deno.test('end_chapter absent or equal to chapter is a same-chapter request', () => {
  assertEquals(parseCrossChapterRange({ chapter: 3, verse_start: 16 }), null)
  assertEquals(parseCrossChapterRange({ chapter: 3, verse_start: 16, verse_end: 17, end_chapter: 3 }), null)
})

Deno.test('valid cross-chapter request is parsed', () => {
  assertEquals(parseCrossChapterRange({ chapter: 10, verse_start: 23, verse_end: 1, end_chapter: 11 }), range)
})

Deno.test('invalid end_chapter values are rejected', () => {
  const bad = [
    { chapter: 10, verse_start: 23, verse_end: 1, end_chapter: 9 },
    { chapter: 10, verse_start: 23, verse_end: 1, end_chapter: '11' },
    { chapter: 10, verse_start: 23, verse_end: 1, end_chapter: 1.5 },
    { chapter: 10, verse_start: 23, end_chapter: 11 },
    { chapter: 1, verse_start: 1, verse_end: 1, end_chapter: 10 },
  ]
  for (const body of bad) {
    const r = parseCrossChapterRange(body)
    assertEquals(r !== null && 'error' in r, true, JSON.stringify(body))
  }
})

Deno.test('builds API.Bible passage id and url', () => {
  assertEquals(buildPassageId('1CO', range), '1CO.10.23-1CO.11.1')
  const url = new URL(buildPassageUrl('bible-id', '1CO.10.23-1CO.11.1'))
  assertEquals(url.pathname, '/v1/bibles/bible-id/passages/1CO.10.23-1CO.11.1')
  assertEquals(url.searchParams.get('fums-version'), '3')
  assertEquals(url.searchParams.get('include-verse-numbers'), 'true')
})

Deno.test('formats localized cross-chapter reference', () => {
  assertEquals(formatCrossChapterReference('1 कुरिन्थियों', range), '1 कुरिन्थियों 10:23-11:1')
})

Deno.test('splits bracketed verse numbers across a chapter boundary', () => {
  const clean = (s: string) => s.replace(/\s+/g, ' ').trim()
  assertEquals(splitNumberedVerses('  [32] Give none offence. [33] Even as I. [1] Be ye followers of me.', clean), [
    { number: 32, text: 'Give none offence.' },
    { number: 33, text: 'Even as I.' },
    { number: 1, text: 'Be ye followers of me.' },
  ])
  assertEquals(splitNumberedVerses('no markers', clean), [])
})
