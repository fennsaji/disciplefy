// ============================================================================
// Locale Loader
// ============================================================================
// Loads all translation files and registers them with the i18n service

import { i18n } from '../services/i18n-service.ts'
import { en } from './en.ts'
import { hi } from './hi.ts'
import { ml } from './ml.ts'

/**
 * Load all locale translations into the i18n service
 * Call this once at application startup before using translations
 */
export function loadAllLocales(): void {
  i18n.loadTranslations('en', en)
  i18n.loadTranslations('hi', hi)
  i18n.loadTranslations('ml', ml)

  console.log('[i18n] Loaded translations for: en, hi, ml')
}

// Export individual locales for testing
export { en, hi, ml }
