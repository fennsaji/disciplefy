/**
 * Pure helpers for cross-chapter passages in fetch-verse
 * (e.g. "1 Corinthians 10:23-11:1"). Kept free of side effects so they can
 * be unit tested without the edge runtime.
 */

/** Longest cross-chapter span accepted (rs-backend allows at most 4 chapters). */
export const MAX_CROSS_CHAPTER_SPAN = 3

export interface CrossChapterRange {
  readonly chapter: number
  readonly verseStart: number
  readonly endChapter: number
  readonly verseEnd: number
}

export interface VerseNumbers {
  readonly chapter: number
  readonly verse_start: number
  readonly verse_end?: number
  readonly end_chapter?: number
}

/** Coerces a positive integer (number or numeric string); null when invalid. */
function toPositiveInt(value: unknown): number | null {
  if (typeof value !== 'number' && typeof value !== 'string') return null
  if (typeof value === 'string' && !/^\s*\d+\s*$/.test(value)) return null
  const n = Number(value)
  return Number.isInteger(n) && n >= 1 ? n : null
}

/**
 * Validates chapter / verse fields before they reach the Bible text URL.
 * Accepts numbers or numeric strings, returns them as numbers, and rejects
 * anything else (e.g. "1/../../bibles") so no request field can alter the path.
 */
export function parseVerseNumbers(body: {
  chapter?: unknown
  verse_start?: unknown
  verse_end?: unknown
  end_chapter?: unknown
}): VerseNumbers | { error: string } {
  const chapter = toPositiveInt(body.chapter)
  const verseStart = toPositiveInt(body.verse_start)
  if (chapter === null || verseStart === null) {
    return { error: 'chapter and verse_start must be positive integers' }
  }
  const present = (v: unknown) => v !== undefined && v !== null
  const verseEnd = present(body.verse_end) ? toPositiveInt(body.verse_end) : undefined
  if (verseEnd === null) return { error: 'verse_end must be a positive integer' }
  const endChapter = present(body.end_chapter) ? toPositiveInt(body.end_chapter) : undefined
  if (endChapter === null) return { error: 'end_chapter must be a positive integer' }
  return { chapter, verse_start: verseStart, verse_end: verseEnd, end_chapter: endChapter }
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

/** "Book C1:V1-C2:V2" with an already-localized book name. */
export function formatCrossChapterReference(book: string, range: CrossChapterRange): string {
  return `${book} ${range.chapter}:${range.verseStart}-${range.endChapter}:${range.verseEnd}`
}
