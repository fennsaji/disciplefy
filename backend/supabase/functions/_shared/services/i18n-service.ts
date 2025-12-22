// ============================================================================
// Internationalization (i18n) Service
// ============================================================================
// Lightweight i18n service with pluralization support for Edge Functions
// Supports English, Hindi, and Malayalam with proper plural forms

// ============================================================================
// Types
// ============================================================================

export type SupportedLocale = 'en' | 'hi' | 'ml'

export interface PluralVariants {
  one: string // Singular form (count === 1)
  other: string // Plural form (count !== 1)
  zero?: string // Optional zero form (count === 0)
}

export interface TranslationValue {
  simple?: string // Simple string without pluralization
  plural?: PluralVariants // Pluralized string with count variants
}

export interface LocaleMessages {
  [key: string]: TranslationValue | LocaleMessages
}

// ============================================================================
// Pluralization Rules
// ============================================================================

/**
 * Get the plural form key based on count and language
 *
 * English: 1 = 'one', else 'other'
 * Hindi: 1 = 'one', else 'other' (वचन vs वचन)
 * Malayalam: 1 = 'one', else 'other' (വാക്യം vs വാക്യങ്ങൾ)
 */
function getPluralForm(count: number, locale: SupportedLocale): keyof PluralVariants {
  // Special case for zero if defined
  if (count === 0) return 'zero'

  // All three languages use the same rule: 1 = singular, else plural
  // Hindi and Malayalam have different word forms, but the logic is the same
  return count === 1 ? 'one' : 'other'
}

// ============================================================================
// Translation Storage
// ============================================================================

const translations: Record<SupportedLocale, LocaleMessages> = {
  en: {},
  hi: {},
  ml: {},
}

// ============================================================================
// I18n Service
// ============================================================================

export class I18nService {
  private currentLocale: SupportedLocale = 'en'

  /**
   * Set the current locale
   */
  setLocale(locale: SupportedLocale): void {
    this.currentLocale = locale
  }

  /**
   * Get the current locale
   */
  getLocale(): SupportedLocale {
    return this.currentLocale
  }

  /**
   * Load translations for a specific locale
   */
  loadTranslations(locale: SupportedLocale, messages: LocaleMessages): void {
    translations[locale] = { ...translations[locale], ...messages }
  }

  /**
   * Translate a key with optional interpolation and pluralization
   *
   * @param key - Translation key (e.g., 'notification.reminder')
   * @param params - Optional parameters for interpolation and count for pluralization
   * @returns Translated string or key if translation not found
   *
   * @example
   * // Simple translation
   * i18n.t('notification.title') // '📚 Review Time'
   *
   * @example
   * // Pluralized translation
   * i18n.t('notification.reminder', { count: 1 }) // '1 verse due today for review'
   * i18n.t('notification.reminder', { count: 5 }) // '5 verses due today for review'
   *
   * @example
   * // With interpolation
   * i18n.t('greeting', { name: 'John' }) // 'Hello, John!'
   */
  t(key: string, params: Record<string, unknown> = {}): string {
    const locale = params.locale as SupportedLocale || this.currentLocale
    const count = params.count as number | undefined

    // Navigate to the translation value
    const value = this.getNestedValue(translations[locale], key)

    // If translation not found, return key as fallback
    if (!value) {
      console.warn(`[i18n] Translation not found for key: ${key} (locale: ${locale})`)
      return key
    }

    // Handle simple string translation
    if (typeof value === 'object' && 'simple' in value && value.simple) {
      return this.interpolate(value.simple, params)
    }

    // Handle pluralized translation
    if (typeof value === 'object' && 'plural' in value && value.plural) {
      if (count === undefined) {
        console.warn(`[i18n] Count parameter required for pluralized translation: ${key}`)
        return key
      }

      const pluralForm = getPluralForm(count, locale)
      const template = value.plural[pluralForm] || value.plural.other

      if (!template) {
        console.warn(`[i18n] Plural form '${pluralForm}' not found for key: ${key}`)
        return key
      }

      return this.interpolate(template, { ...params, count })
    }

    console.warn(`[i18n] Invalid translation format for key: ${key}`)
    return key
  }

  /**
   * Get a nested value from an object using dot notation
   *
   * @example
   * getNestedValue({ notification: { title: 'Hello' } }, 'notification.title')
   * // Returns 'Hello'
   */
  private getNestedValue(obj: LocaleMessages, path: string): TranslationValue | undefined {
    const keys = path.split('.')
    let current: unknown = obj

    for (const key of keys) {
      if (current && typeof current === 'object' && key in current) {
        current = (current as Record<string, unknown>)[key]
      } else {
        return undefined
      }
    }

    return current as TranslationValue
  }

  /**
   * Interpolate variables in a template string
   *
   * @example
   * interpolate('Hello, {{name}}!', { name: 'John' })
   * // Returns 'Hello, John!'
   */
  private interpolate(template: string, params: Record<string, unknown>): string {
    return template.replace(/\{\{(\w+)\}\}/g, (_, key) => {
      const value = params[key]
      return value !== undefined ? String(value) : `{{${key}}}`
    })
  }
}

// ============================================================================
// Singleton Instance
// ============================================================================

/**
 * Global i18n service instance
 * Use this instance throughout the application
 */
export const i18n = new I18nService()

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Load all locale files and initialize the i18n service
 * Call this once at application startup
 */
export function initializeI18n(defaultLocale: SupportedLocale = 'en'): void {
  i18n.setLocale(defaultLocale)
  console.log(`[i18n] Initialized with locale: ${defaultLocale}`)
}

/**
 * Get translation with automatic locale detection
 * Convenience wrapper around i18n.t()
 */
export function t(key: string, params?: Record<string, unknown>): string {
  return i18n.t(key, params)
}
