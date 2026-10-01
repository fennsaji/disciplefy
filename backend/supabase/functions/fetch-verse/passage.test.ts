// Run with: deno test passage.test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { formatCrossChapterReference, parseCrossChapterRange } from './passage.ts'

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

Deno.test('formats localized cross-chapter reference', () => {
  assertEquals(formatCrossChapterReference('1 कुरिन्थियों', range), '1 कुरिन्थियों 10:23-11:1')
})

import { parseVerseNumbers } from './passage.ts'

Deno.test('path traversal in verse fields is rejected', () => {
  for (const bad of ['1/../../../bibles?x=', '3.16', '-1', '0', '', 'abc', 1.5, {}]) {
    assertEquals('error' in parseVerseNumbers({ chapter: 3, verse_start: bad }), true, String(bad))
    assertEquals('error' in parseVerseNumbers({ chapter: bad, verse_start: 1 }), true, String(bad))
    assertEquals('error' in parseVerseNumbers({ chapter: 3, verse_start: 1, verse_end: bad }), true, String(bad))
    assertEquals('error' in parseVerseNumbers({ chapter: 3, verse_start: 1, end_chapter: bad }), true, String(bad))
  }
})

Deno.test('numeric strings are coerced to numbers', () => {
  assertEquals(parseVerseNumbers({ chapter: '3', verse_start: '16', verse_end: '17', end_chapter: '4' }),
    { chapter: 3, verse_start: 16, verse_end: 17, end_chapter: 4 })
  assertEquals(parseVerseNumbers({ chapter: 3, verse_start: 16 }),
    { chapter: 3, verse_start: 16, verse_end: undefined, end_chapter: undefined })
})

Deno.test('chapter "3" with end_chapter 3 is same-chapter after coercion', () => {
  const n = parseVerseNumbers({ chapter: '3', verse_start: 16, verse_end: 18, end_chapter: 3 })
  assertEquals('error' in n, false)
  assertEquals(parseCrossChapterRange(n as { chapter: number; verse_start: number }), null)
})
