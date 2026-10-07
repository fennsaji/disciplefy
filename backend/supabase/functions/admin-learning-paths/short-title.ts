/**
 * Short display titles for learning paths (admin input).
 *
 * Mirrors the database CHECK (char_length(short_title) <= 28): length is
 * counted in code points, as Postgres counts characters.
 */

export const SHORT_TITLE_MAX = 28

/** Trimmed value; blank becomes null (clears it); undefined stays "not sent". */
export function normalizeShortTitle(value: string | null | undefined): string | null | undefined {
  if (value === undefined) return undefined
  if (value === null) return null
  const trimmed = String(value).trim()
  return trimmed ? trimmed : null
}

function invalid(value: unknown): boolean {
  if (value === undefined || value === null) return false
  if (typeof value !== 'string') return true
  const trimmed = value.trim()
  return [...trimmed].length > SHORT_TITLE_MAX
}

export interface ShortTitleInput {
  short_title?: string | null
  translations?: Record<string, { short_title?: string | null } | undefined>
}

/** Field paths whose short title is not a string of at most 28 characters. */
export function shortTitleErrors(body: ShortTitleInput): string[] {
  const errors: string[] = []
  if (invalid(body.short_title)) errors.push('short_title')
  for (const [lang, trans] of Object.entries(body.translations ?? {})) {
    if (trans && invalid(trans.short_title)) errors.push(`translations.${lang}.short_title`)
  }
  return errors
}
