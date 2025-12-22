// ============================================================================
// English (en) Translations
// ============================================================================
// Translation resources for English notifications and UI text

import type { LocaleMessages } from '../services/i18n-service.ts'

export const en: LocaleMessages = {
  notification: {
    memoryVerse: {
      title: {
        simple: '📚 Review Time',
      },
      reminder: {
        plural: {
          one: '{{count}} verse due today for review',
          other: '{{count}} verses due today for review',
          zero: 'No verses due for review',
        },
      },
      overdue: {
        plural: {
          one: '{{count}} verse overdue for review',
          other: '{{count}} verses overdue for review',
        },
      },
    },
  },
}
