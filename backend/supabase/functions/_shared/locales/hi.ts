// ============================================================================
// Hindi (hi) Translations
// ============================================================================
// Translation resources for Hindi notifications and UI text
// वचन (vachan) = verse; आज (aaj) = today; याद करना (yaad karna) = to remember/review

import type { LocaleMessages } from '../services/i18n-service.ts'

export const hi: LocaleMessages = {
  notification: {
    memoryVerse: {
      title: {
        simple: '📚 समीक्षा करें',
      },
      reminder: {
        plural: {
          // Hindi: वचन stays same in plural, but can add context
          // "{{count}} वचन आज याद करने के लिए" = "{{count}} verse(s) to remember today"
          one: '{{count}} वचन आज याद करने के लिए',
          other: '{{count}} वचन आज याद करने के लिए',
          zero: 'आज कोई वचन याद करने के लिए नहीं',
        },
      },
      overdue: {
        plural: {
          // "{{count}} वचन समीक्षा के लिए बाकी" = "{{count}} verse(s) pending for review"
          one: '{{count}} वचन समीक्षा के लिए बाकी',
          other: '{{count}} वचन समीक्षा के लिए बाकी',
        },
      },
    },
  },
}
