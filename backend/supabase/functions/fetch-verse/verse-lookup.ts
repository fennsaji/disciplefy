/**
 * Verse lookup for fetch-verse: turns the app's request into a self-hosted
 * Bible text read and shapes the response the installed apps expect.
 * Free of edge-runtime side effects so it can be tested with a fake fetch.
 */

import {
  BibleTextNotFoundError,
  BOOK_CODES,
  fetchPassage,
  resolveVersion,
  type BibleLanguage,
  type FetchLike,
} from '../_shared/services/bible-text-service.ts'
import { HINDI_BOOK_NAMES, MALAYALAM_BOOK_NAMES, LOCALIZED_VARIANTS_TO_ENGLISH } from '../_shared/utils/bible-book-normalizer.ts'
import { formatCrossChapterReference, type CrossChapterRange } from './passage.ts'

export interface VerseItem {
  number: number
  text: string
  chapter?: number // Only set for cross-chapter passages
}

export interface VerseLookupData {
  reference: string
  localizedReference: string
  text: string
  verses?: VerseItem[] // Per-verse breakdown for ranges (absent for single verses / chapters)
  translation: string
  translationAbbreviation: string
  version: string
  attribution: string
  language: BibleLanguage
}

export interface VerseLookupRequest {
  readonly book: string
  readonly chapter: number
  readonly verse_start: number
  readonly verse_end?: number
  readonly language: BibleLanguage
  readonly version?: string
}

const HINDI_TO_ENGLISH: Record<string, string> = Object.fromEntries(
  Object.entries(HINDI_BOOK_NAMES).map(([en, hi]) => [hi, en]),
)
const MALAYALAM_TO_ENGLISH: Record<string, string> = Object.fromEntries(
  Object.entries(MALAYALAM_BOOK_NAMES).map(([en, ml]) => [ml, en]),
)

/** English canonical book name for English, Hindi, Malayalam or variant input; input unchanged when unknown. */
export function normalizeBookName(book: string): string {
  if (BOOK_CODES[book]) return book
  const mapped = HINDI_TO_ENGLISH[book] ?? MALAYALAM_TO_ENGLISH[book] ??
    LOCALIZED_VARIANTS_TO_ENGLISH[book] ?? LOCALIZED_VARIANTS_TO_ENGLISH[book.toLowerCase()]
  if (mapped) return mapped
  const lower = book.toLowerCase()
  return Object.keys(BOOK_CODES).find(k => k.toLowerCase() === lower) ?? book
}

export function getLocalizedBookName(book: string, language: BibleLanguage): string {
  if (language === 'hi') return HINDI_BOOK_NAMES[book] || book
  if (language === 'ml') return MALAYALAM_BOOK_NAMES[book] || book
  return book
}

export class VerseLookupError extends Error {
  constructor(readonly code: 'VALIDATION_ERROR' | 'NOT_FOUND', message: string, readonly status: number) {
    super(message)
  }
}

/**
 * Same-chapter requests, whole chapters (verse_start 1 + verse_end 999, as the
 * app sends them) and cross-chapter passages all go through one rs-backend call.
 */
export async function lookupVerses(
  body: VerseLookupRequest,
  crossChapter: CrossChapterRange | null,
  fetchImpl: FetchLike = fetch,
): Promise<VerseLookupData> {
  const englishBook = normalizeBookName(body.book)
  const bookCode = BOOK_CODES[englishBook]
  if (!bookCode) throw new VerseLookupError('VALIDATION_ERROR', `Unknown book name: ${body.book}`, 400)

  const version = resolveVersion(body.language, body.version)
  const localizedBook = getLocalizedBookName(englishBook, body.language)
  const isChapterOnly = !crossChapter && body.verse_start === 1 && body.verse_end === 999
  const isRange = !crossChapter && !isChapterOnly && !!body.verse_end && body.verse_end > body.verse_start

  let suffix: string
  if (crossChapter) {
    suffix = formatCrossChapterReference('', crossChapter).trim()
  } else if (isChapterOnly) {
    suffix = `${body.chapter}`
  } else if (isRange) {
    suffix = `${body.chapter}:${body.verse_start}-${body.verse_end}`
  } else {
    suffix = `${body.chapter}:${body.verse_start}`
  }
  const reference = `${englishBook} ${suffix}`

  let passage
  try {
    passage = await fetchPassage(version.id, {
      book: bookCode,
      chapter: body.chapter,
      ...(isChapterOnly ? {} : { verseStart: body.verse_start }),
      ...(crossChapter
        ? { verseEnd: crossChapter.verseEnd, endChapter: crossChapter.endChapter }
        : isRange ? { verseEnd: body.verse_end } : {}),
    }, fetchImpl)
  } catch (error) {
    if (error instanceof BibleTextNotFoundError) {
      throw new VerseLookupError('NOT_FOUND', `Verse not found: ${reference}`, 404)
    }
    throw error
  }

  const verses: VerseItem[] | undefined = crossChapter
    ? passage.verses.map(v => ({ number: v.verse, text: v.text, chapter: v.chapter }))
    : isRange ? passage.verses.map(v => ({ number: v.verse, text: v.text })) : undefined

  return {
    reference,
    localizedReference: `${localizedBook} ${suffix}`,
    text: passage.text,
    ...(verses ? { verses } : {}),
    translation: version.name,
    translationAbbreviation: version.abbreviation,
    version: version.id,
    attribution: passage.attribution,
    language: body.language,
  }
}
