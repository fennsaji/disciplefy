// backend/supabase/functions/telegram-daily-verse/message.ts
/**
 * Composes the daily verse post. Kept apart from the job so it can be tested
 * without a token or a database.
 *
 * Mirrors the app's verse share text (ShareLinks.verseMessage): the reference
 * cites its translation inline, then the text, then the daily-verse link.
 */

export type VerseLanguage = 'en' | 'hi' | 'ml'

/** Same link the app's daily verse share uses (ShareLinks.dailyVerse). */
export const DAILY_VERSE_URL = 'https://go.disciplefy.in/daily-verse'

/** Translation cited per language, matching dailyVerseTranslationAbbr in the app. */
export const TRANSLATION_ABBR: Record<VerseLanguage, string> = { en: 'KJV', hi: 'IRV', ml: 'IRV' }

const HEADER: Record<VerseLanguage, string> = {
  en: "🌅 Today's Verse",
  hi: '🌅 आज का वचन',
  ml: '🌅 ഇന്നത്തെ വചനം',
}

export interface DailyVerseRecord {
  reference: string
  referenceTranslations?: Partial<Record<VerseLanguage, string>>
  translations?: { esv?: string; hi?: string; ml?: string; hindi?: string; malayalam?: string }
}

/** Verse text and localized reference for a language; null when the text is missing. */
export function verseFor(
  verse: DailyVerseRecord,
  language: VerseLanguage,
): { reference: string; text: string } | null {
  const t = verse.translations ?? {}
  const raw = language === 'en' ? t.esv : language === 'hi' ? (t.hi ?? t.hindi) : (t.ml ?? t.malayalam)
  const text = raw?.trim()
  if (!text) return null
  const reference = verse.referenceTranslations?.[language]?.trim() || verse.reference
  return { reference, text }
}

export function buildDailyVerseMessage(language: VerseLanguage, reference: string, text: string): string {
  return [
    HEADER[language],
    '',
    `${reference} (${TRANSLATION_ABBR[language]})`,
    '',
    text,
    '',
    `📱 ${DAILY_VERSE_URL}`,
  ].join('\n')
}
