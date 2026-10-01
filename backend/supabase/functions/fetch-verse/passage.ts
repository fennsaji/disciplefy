/**
 * Pure helpers for cross-chapter passages in fetch-verse
 * (e.g. "1 Corinthians 10:23-11:1"). Kept free of side effects so they can
 * be unit tested without the edge runtime.
 */

/** Longest cross-chapter span accepted, to bound API.Bible usage. */
export const MAX_CROSS_CHAPTER_SPAN = 3

export interface CrossChapterRange {
  readonly chapter: number
  readonly verseStart: number
  readonly endChapter: number
  readonly verseEnd: number
}

/**
 * Validates the optional `end_chapter` field. Returns the cross-chapter range
 * when the request spans chapters, `null` for same-chapter requests (field
 * absent or equal to `chapter`), or an error message when invalid.
 */
export function parseCrossChapterRange(body: {
  chapter: unknown
  verse_start: unknown
  verse_end?: unknown
  end_chapter?: unknown
}): CrossChapterRange | null | { error: string } {
  if (body.end_chapter === undefined || body.end_chapter === null) return null

  const endChapter = body.end_chapter
  if (typeof endChapter !== 'number' || !Number.isInteger(endChapter) || endChapter < 1) {
    return { error: 'end_chapter must be a positive integer' }
  }
  const chapter = body.chapter as number
  if (endChapter === chapter) return null
  if (endChapter < chapter) {
    return { error: 'end_chapter must not be before chapter' }
  }
  if (endChapter - chapter > MAX_CROSS_CHAPTER_SPAN) {
    return { error: `Passages may span at most ${MAX_CROSS_CHAPTER_SPAN + 1} chapters` }
  }
  const verseEnd = body.verse_end
  if (typeof verseEnd !== 'number' || !Number.isInteger(verseEnd) || verseEnd < 1) {
    return { error: 'verse_end is required when end_chapter is given' }
  }
  return {
    chapter,
    verseStart: body.verse_start as number,
    endChapter,
    verseEnd,
  }
}

/** API.Bible passage id, e.g. `1CO.10.23-1CO.11.1`. */
export function buildPassageId(bookCode: string, range: CrossChapterRange): string {
  return `${bookCode}.${range.chapter}.${range.verseStart}-${bookCode}.${range.endChapter}.${range.verseEnd}`
}

/** API.Bible passages URL returning plain text with bracketed verse numbers. */
export function buildPassageUrl(bibleId: string, passageId: string): string {
  const params = new URLSearchParams({
    'content-type': 'text',
    'include-notes': 'false',
    'include-titles': 'false',
    'include-chapter-numbers': 'false',
    'include-verse-numbers': 'true', // "[23] ..." markers, split into verses below
    'fums-version': '3',
  })
  return `https://api.scripture.api.bible/v1/bibles/${bibleId}/passages/${passageId}?${params.toString()}`
}

/** "Book C1:V1-C2:V2" with an already-localized book name. */
export function formatCrossChapterReference(book: string, range: CrossChapterRange): string {
  return `${book} ${range.chapter}:${range.verseStart}-${range.endChapter}:${range.verseEnd}`
}

/**
 * Splits passage text carrying "[n]" verse markers into verse items.
 * Text before the first marker is ignored. Returns an empty list when no
 * markers are present.
 */
export function splitNumberedVerses(
  text: string,
  clean: (s: string) => string,
): { number: number; text: string }[] {
  const items: { number: number; text: string }[] = []
  const marker = /\[(\d+)\]/g
  const matches = [...text.matchAll(marker)]
  for (let i = 0; i < matches.length; i++) {
    const start = matches[i].index! + matches[i][0].length
    const end = i + 1 < matches.length ? matches[i + 1].index! : text.length
    const verseText = clean(text.slice(start, end))
    if (verseText) items.push({ number: Number(matches[i][1]), text: verseText })
  }
  return items
}
