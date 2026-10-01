/**
 * Body shape the daily-verse endpoint returns, built from the
 * daily_verses_cache row (DailyVerseService). Shared so tests can assert the
 * Telegram post carries exactly what the app shows.
 *
 * `translations.esv` is a legacy key name kept for installed apps: it holds
 * KJV text. `hindi` / `malayalam` hold IRV text.
 */
export interface DailyVerseResponseBody {
  readonly id?: string
  readonly reference: string
  readonly referenceTranslations: { readonly en: string; readonly hi: string; readonly ml: string }
  readonly date: string
  readonly translations: { readonly esv?: string; readonly hindi?: string; readonly malayalam?: string }
}

export interface ServiceVerse {
  id?: string
  reference: string
  referenceTranslations: { en: string; hi: string; ml: string }
  translations: { esv: string; hi: string; ml: string }
  date: string
}

/** Only translations with content are included. */
export function toDailyVerseResponseBody(v: ServiceVerse): DailyVerseResponseBody {
  return {
    id: v.id,
    reference: v.reference,
    referenceTranslations: { en: v.referenceTranslations.en, hi: v.referenceTranslations.hi, ml: v.referenceTranslations.ml },
    date: v.date,
    translations: {
      ...(v.translations.esv ? { esv: v.translations.esv } : {}),
      ...(v.translations.hi ? { hindi: v.translations.hi } : {}),
      ...(v.translations.ml ? { malayalam: v.translations.ml } : {}),
    },
  }
}
