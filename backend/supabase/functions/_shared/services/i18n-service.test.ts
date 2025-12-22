// ============================================================================
// i18n Service Tests
// ============================================================================
// Unit tests for the i18n service with pluralization

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { I18nService } from './i18n-service.ts'
import type { LocaleMessages } from './i18n-service.ts'

// Test translations
const testTranslationsEn: LocaleMessages = {
  notification: {
    memoryVerse: {
      title: {
        simple: '📚 Review Time',
      },
      reminder: {
        plural: {
          one: '{{count}} verse due today',
          other: '{{count}} verses due today',
          zero: 'No verses due today',
        },
      },
    },
  },
  greeting: {
    simple: 'Hello, {{name}}!',
  },
}

const testTranslationsHi: LocaleMessages = {
  notification: {
    memoryVerse: {
      title: {
        simple: '📚 समीक्षा करें',
      },
      reminder: {
        plural: {
          one: '{{count}} वचन आज याद करने के लिए',
          other: '{{count}} वचन आज याद करने के लिए',
        },
      },
    },
  },
}

const testTranslationsMl: LocaleMessages = {
  notification: {
    memoryVerse: {
      title: {
        simple: '📚 അവലോകനം',
      },
      reminder: {
        plural: {
          one: '{{count}} വാക്യം ഇന്ന് ഓർമ്മിക്കാൻ',
          other: '{{count}} വാക്യങ്ങൾ ഇന്ന് ഓർമ്മിക്കാൻ',
        },
      },
    },
  },
}

Deno.test('i18n Service - Simple Translation', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('en', testTranslationsEn)
  i18n.setLocale('en')

  const result = i18n.t('notification.memoryVerse.title')
  assertEquals(result, '📚 Review Time')
})

Deno.test('i18n Service - Simple Translation with Interpolation', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('en', testTranslationsEn)
  i18n.setLocale('en')

  const result = i18n.t('greeting', { name: 'John' })
  assertEquals(result, 'Hello, John!')
})

Deno.test('i18n Service - Pluralization English (singular)', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('en', testTranslationsEn)
  i18n.setLocale('en')

  const result = i18n.t('notification.memoryVerse.reminder', { count: 1 })
  assertEquals(result, '1 verse due today')
})

Deno.test('i18n Service - Pluralization English (plural)', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('en', testTranslationsEn)
  i18n.setLocale('en')

  const result = i18n.t('notification.memoryVerse.reminder', { count: 5 })
  assertEquals(result, '5 verses due today')
})

Deno.test('i18n Service - Pluralization English (zero)', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('en', testTranslationsEn)
  i18n.setLocale('en')

  const result = i18n.t('notification.memoryVerse.reminder', { count: 0 })
  assertEquals(result, 'No verses due today')
})

Deno.test('i18n Service - Pluralization Hindi (singular)', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('hi', testTranslationsHi)
  i18n.setLocale('hi')

  const result = i18n.t('notification.memoryVerse.reminder', { count: 1 })
  assertEquals(result, '1 वचन आज याद करने के लिए')
})

Deno.test('i18n Service - Pluralization Hindi (plural)', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('hi', testTranslationsHi)
  i18n.setLocale('hi')

  const result = i18n.t('notification.memoryVerse.reminder', { count: 5 })
  assertEquals(result, '5 वचन आज याद करने के लिए')
})

Deno.test('i18n Service - Pluralization Malayalam (singular)', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('ml', testTranslationsMl)
  i18n.setLocale('ml')

  const result = i18n.t('notification.memoryVerse.reminder', { count: 1 })
  assertEquals(result, '1 വാക്യം ഇന്ന് ഓർമ്മിക്കാൻ')
})

Deno.test('i18n Service - Pluralization Malayalam (plural)', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('ml', testTranslationsMl)
  i18n.setLocale('ml')

  const result = i18n.t('notification.memoryVerse.reminder', { count: 5 })
  assertEquals(result, '5 വാക്യങ്ങൾ ഇന്ന് ഓർമ്മിക്കാൻ')
})

Deno.test('i18n Service - Locale Override', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('en', testTranslationsEn)
  i18n.loadTranslations('hi', testTranslationsHi)
  i18n.setLocale('en')

  // Override locale in params
  const result = i18n.t('notification.memoryVerse.title', { locale: 'hi' })
  assertEquals(result, '📚 समीक्षा करें')
})

Deno.test('i18n Service - Missing Translation Fallback', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('en', testTranslationsEn)
  i18n.setLocale('en')

  const result = i18n.t('nonexistent.key')
  assertEquals(result, 'nonexistent.key') // Returns key as fallback
})

Deno.test('i18n Service - Missing Plural Count Parameter', () => {
  const i18n = new I18nService()
  i18n.loadTranslations('en', testTranslationsEn)
  i18n.setLocale('en')

  // Should return key if count is missing for pluralized translation
  const result = i18n.t('notification.memoryVerse.reminder')
  assertEquals(result, 'notification.memoryVerse.reminder')
})
