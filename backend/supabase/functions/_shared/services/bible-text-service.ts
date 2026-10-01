/**
 * Bible Text Service
 *
 * Client for the self-hosted Bible text served by rs-backend
 * (`GET {BIBLE_TEXT_URL}/api/v1/bible/{version}/verses`). The texts are public
 * domain or CC BY-SA 4.0, so they may be stored, shown, sent to the LLM and
 * read aloud; CC BY-SA texts must be shown with their attribution line.
 *
 * Versions:
 * - bsb     Berean Standard Bible (English default, public domain)
 * - kjv     King James Version (English, public domain)
 * - irv-hi  Indian Revised Version Hindi 2019 (Hindi default, CC BY-SA 4.0)
 * - irv-ml  Indian Revised Version Malayalam (Malayalam default, CC BY-SA 4.0)
 * - sv-ml   Sathyavedapusthakam 1910, contemporary orthography (Malayalam, CC BY-SA 4.0)
 *
 * Env: BIBLE_TEXT_URL (rs-backend base URL, default https://api.disciplefy.in).
 */

export type BibleLanguage = 'en' | 'hi' | 'ml'
export type BibleVersionId = 'bsb' | 'kjv' | 'irv-hi' | 'irv-ml' | 'sv-ml'

export interface BibleVersionInfo {
  readonly id: BibleVersionId
  readonly language: BibleLanguage
  readonly abbreviation: string
  readonly name: string
  readonly attribution: string
}

export const BIBLE_VERSIONS: Record<BibleVersionId, BibleVersionInfo> = {
  bsb: {
    id: 'bsb', language: 'en', abbreviation: 'BSB', name: 'Berean Standard Bible (BSB)',
    attribution: 'The Holy Bible, Berean Standard Bible, BSB. Public domain.',
  },
  kjv: {
    id: 'kjv', language: 'en', abbreviation: 'KJV', name: 'King James Version (KJV)',
    attribution: 'King James Version. Public domain.',
  },
  'irv-hi': {
    id: 'irv-hi', language: 'hi', abbreviation: 'IRV', name: 'Indian Revised Version Hindi 2019',
    attribution: 'Indian Revised Version (IRV) Hindi - 2019, © 2017, 2018, 2019 Bridge Connectivity Solutions. Licensed under CC BY-SA 4.0. Notes and cross references removed.',
  },
  'irv-ml': {
    id: 'irv-ml', language: 'ml', abbreviation: 'IRV', name: 'Indian Revised Version Malayalam',
    attribution: 'Indian Revised Version (IRV) Malayalam, © 2017, 2019 Bridge Connectivity Solutions. Licensed under CC BY-SA 4.0. Notes and cross references removed.',
  },
  'sv-ml': {
    id: 'sv-ml', language: 'ml', abbreviation: 'SV 1910', name: 'Sathyavedapusthakam 1910',
    attribution: 'Malayalam Bible 1910 (Sathyavedapusthakam), contemporary orthography edition © 2015 The Free Bible Foundation. Licensed under CC BY-SA 4.0. Notes removed.',
  },
}

/** Version used when a request names none: BSB, IRV Hindi, IRV Malayalam. */
export const DEFAULT_VERSION: Record<BibleLanguage, BibleVersionId> = {
  en: 'bsb',
  hi: 'irv-hi',
  ml: 'irv-ml',
}

/**
 * The version to read for a language. A requested version is honoured only
 * when it is known and belongs to that language; anything else falls back to
 * the language default.
 */
export function resolveVersion(language: BibleLanguage, requested?: unknown): BibleVersionInfo {
  if (typeof requested === 'string') {
    const v = BIBLE_VERSIONS[requested.trim().toLowerCase() as BibleVersionId]
    if (v && v.language === language) return v
  }
  return BIBLE_VERSIONS[DEFAULT_VERSION[language]]
}

/** English book name (and common aliases) → USFM book code. */
export const BOOK_CODES: Record<string, string> = {
  'Genesis': 'GEN', 'Exodus': 'EXO', 'Leviticus': 'LEV', 'Numbers': 'NUM', 'Deuteronomy': 'DEU',
  'Joshua': 'JOS', 'Judges': 'JDG', 'Ruth': 'RUT', '1 Samuel': '1SA', '2 Samuel': '2SA',
  '1 Kings': '1KI', '2 Kings': '2KI', '1 Chronicles': '1CH', '2 Chronicles': '2CH',
  'Ezra': 'EZR', 'Nehemiah': 'NEH', 'Esther': 'EST', 'Job': 'JOB', 'Psalms': 'PSA',
  'Proverbs': 'PRO', 'Ecclesiastes': 'ECC', 'Song of Solomon': 'SNG', 'Isaiah': 'ISA',
  'Jeremiah': 'JER', 'Lamentations': 'LAM', 'Ezekiel': 'EZK', 'Daniel': 'DAN',
  'Hosea': 'HOS', 'Joel': 'JOL', 'Amos': 'AMO', 'Obadiah': 'OBA', 'Jonah': 'JON',
  'Micah': 'MIC', 'Nahum': 'NAM', 'Habakkuk': 'HAB', 'Zephaniah': 'ZEP', 'Haggai': 'HAG',
  'Zechariah': 'ZEC', 'Malachi': 'MAL',
  'Matthew': 'MAT', 'Mark': 'MRK', 'Luke': 'LUK', 'John': 'JHN', 'Acts': 'ACT',
  'Romans': 'ROM', '1 Corinthians': '1CO', '2 Corinthians': '2CO', 'Galatians': 'GAL',
  'Ephesians': 'EPH', 'Philippians': 'PHP', 'Colossians': 'COL', '1 Thessalonians': '1TH',
  '2 Thessalonians': '2TH', '1 Timothy': '1TI', '2 Timothy': '2TI', 'Titus': 'TIT',
  'Philemon': 'PHM', 'Hebrews': 'HEB', 'James': 'JAS', '1 Peter': '1PE', '2 Peter': '2PE',
  '1 John': '1JN', '2 John': '2JN', '3 John': '3JN', 'Jude': 'JUD', 'Revelation': 'REV',
}

const BOOK_ALIASES: Record<string, string> = {
  'Psalm': 'PSA', 'Song of Songs': 'SNG', 'Canticles': 'SNG', 'Canticle of Canticles': 'SNG',
  '1 Sam': '1SA', '2 Sam': '2SA', '1 Kgs': '1KI', '2 Kgs': '2KI', '1 Chr': '1CH', '2 Chr': '2CH',
  '1 Cor': '1CO', '2 Cor': '2CO', '1 Thess': '1TH', '2 Thess': '2TH', '1 Tim': '1TI',
  '2 Tim': '2TI', '1 Pet': '1PE', '2 Pet': '2PE', 'Rev': 'REV', 'Revelations': 'REV',
}

/** USFM code for an English book name or alias (case-insensitive); undefined when unknown. */
export function bookCodeFor(name: string): string | undefined {
  const n = name.trim().replace(/\s+/g, ' ')
  const exact = BOOK_CODES[n] ?? BOOK_ALIASES[n]
  if (exact) return exact
  const lower = n.toLowerCase()
  for (const table of [BOOK_CODES, BOOK_ALIASES]) {
    const key = Object.keys(table).find(k => k.toLowerCase() === lower)
    if (key) return table[key]
  }
  return undefined
}

export interface PassageRequest {
  readonly book: string // USFM code
  readonly chapter: number
  readonly verseStart?: number // omitted = whole chapter
  readonly verseEnd?: number
  readonly endChapter?: number
}

export interface PassageVerse {
  readonly chapter: number
  readonly verse: number
  readonly verse_end?: number // set when the source merges verses, e.g. 24-25
  readonly text: string
}

export interface Passage {
  readonly version: BibleVersionInfo
  readonly book: string
  readonly bookName: string
  /** Reference with the translation's own (localized) book name. */
  readonly reference: string
  readonly verses: PassageVerse[]
  readonly text: string
  readonly attribution: string
}

/** The requested book/chapter/verse does not exist in the version. */
export class BibleTextNotFoundError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'BibleTextNotFoundError'
  }
}

export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>

export function bibleTextBaseUrl(): string {
  const url = Deno.env.get('BIBLE_TEXT_URL')?.trim() || 'https://api.disciplefy.in'
  return url.replace(/\/+$/, '')
}

/**
 * Fetch with timeout support
 */
export async function fetchWithTimeout(
  url: string,
  options: RequestInit = {},
  timeoutMs = 30000,
  fetchImpl: FetchLike = fetch,
): Promise<Response> {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetchImpl(url, { ...options, signal: controller.signal })
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`Request timeout after ${timeoutMs}ms: ${url}`)
    }
    throw error
  } finally {
    clearTimeout(timeout)
  }
}

export function buildPassageUrl(baseUrl: string, version: BibleVersionId, req: PassageRequest): string {
  const params = new URLSearchParams({ book: req.book, chapter: String(req.chapter) })
  if (req.verseStart !== undefined) params.set('verse_start', String(req.verseStart))
  if (req.verseEnd !== undefined) params.set('verse_end', String(req.verseEnd))
  if (req.endChapter !== undefined && req.endChapter !== req.chapter) {
    params.set('end_chapter', String(req.endChapter))
  }
  return `${baseUrl}/api/v1/bible/${encodeURIComponent(version)}/verses?${params.toString()}`
}

/**
 * Reads a passage from rs-backend. Retries network errors and 5xx twice;
 * 404 → BibleTextNotFoundError, other 4xx → Error without retry.
 */
export async function fetchPassage(
  version: BibleVersionId,
  req: PassageRequest,
  fetchImpl: FetchLike = fetch,
): Promise<Passage> {
  const url = buildPassageUrl(bibleTextBaseUrl(), version, req)
  let lastError: unknown
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetchWithTimeout(url, { headers: { accept: 'application/json' } }, 8000, fetchImpl)
      if (res.status === 404 || res.status === 400) {
        const body = await res.json().catch(() => null)
        const message = body?.error?.message ?? `Passage not found (${res.status})`
        if (res.status === 404) throw new BibleTextNotFoundError(message)
        throw new Error(`Bible text request rejected: ${message}`)
      }
      if (!res.ok) throw new RetryableError(`Bible text request failed: ${res.status}`)
      const body = await res.json()
      const d = body?.data
      if (!d || !Array.isArray(d.verses)) throw new RetryableError('Bible text response malformed')
      const verses: PassageVerse[] = d.verses.map((v: PassageVerse) => ({
        chapter: v.chapter,
        verse: v.verse,
        ...(v.verse_end ? { verse_end: v.verse_end } : {}),
        text: v.text,
      }))
      return {
        version: BIBLE_VERSIONS[version],
        book: d.book,
        bookName: d.book_name,
        reference: d.reference,
        verses,
        text: typeof d.text === 'string' ? d.text : verses.map(v => v.text).join(' '),
        attribution: d.attribution ?? BIBLE_VERSIONS[version].attribution,
      }
    } catch (error) {
      if (!(error instanceof RetryableError) && !isNetworkError(error)) throw error
      lastError = error
      if (attempt < 3) await new Promise(r => setTimeout(r, 200 * attempt))
    }
  }
  throw lastError instanceof Error ? lastError : new Error(String(lastError))
}

class RetryableError extends Error {}

function isNetworkError(error: unknown): boolean {
  return error instanceof TypeError || (error instanceof Error && error.message.startsWith('Request timeout'))
}

/** "John 3:16", "Psalm 23:1-3", "1 Corinthians 10:23-11:1" → book code + numbers. */
export function parseReference(reference: string): PassageRequest {
  const m = reference.trim().match(/^((?:[1-3]\s*)?[A-Za-z][A-Za-z\s]*?)\s+(\d+):(\d+)(?:\s*[-–]\s*(?:(\d+):)?(\d+))?$/)
  if (!m) throw new Error(`Invalid Bible reference format: ${reference}`)
  const [, bookName, ch, vs, endCh, ve] = m
  const book = bookCodeFor(bookName)
  if (!book) throw new Error(`Unknown book name: ${bookName}`)
  const chapter = Number(ch)
  return {
    book,
    chapter,
    verseStart: Number(vs),
    verseEnd: ve ? Number(ve) : Number(vs),
    ...(endCh && Number(endCh) !== chapter ? { endChapter: Number(endCh) } : {}),
  }
}

export interface BibleVerse {
  reference: string
  text: string
  translation: string
  language: BibleLanguage
}

/** Verse text for an English reference in a language's default (or given) version. */
export async function fetchBibleVerse(
  reference: string,
  language: BibleLanguage,
  version?: BibleVersionId,
  fetchImpl: FetchLike = fetch,
): Promise<BibleVerse> {
  const v = resolveVersion(language, version)
  const passage = await fetchPassage(v.id, parseReference(reference), fetchImpl)
  return { reference, text: passage.text, translation: v.name, language }
}

/**
 * Verse text in all three languages. English is required; Hindi/Malayalam
 * fall back to empty text when they fail.
 */
export async function fetchVerseAllLanguages(
  reference: string,
  fetchImpl: FetchLike = fetch,
): Promise<Record<BibleLanguage, BibleVerse>> {
  const langs: BibleLanguage[] = ['en', 'hi', 'ml']
  const results = await Promise.allSettled(langs.map(l => fetchBibleVerse(reference, l, undefined, fetchImpl)))
  const out = {} as Record<BibleLanguage, BibleVerse>
  results.forEach((r, i) => {
    const language = langs[i]
    if (r.status === 'fulfilled') {
      out[language] = r.value
      return
    }
    if (language === 'en') throw new Error(`English verse text required but failed: ${r.reason}`)
    console.error(`[BibleText] ${language} text failed for ${reference}:`, r.reason instanceof Error ? r.reason.message : r.reason)
    out[language] = { reference, text: '', translation: resolveVersion(language).name, language }
  })
  return out
}
