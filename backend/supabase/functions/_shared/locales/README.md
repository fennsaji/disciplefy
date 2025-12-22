# i18n Translation System

Lightweight internationalization (i18n) service for Supabase Edge Functions with proper pluralization support for English, Hindi, and Malayalam.

## Overview

This i18n system provides:
- ✅ **Proper pluralization** for all supported languages (en, hi, ml)
- ✅ **Language-specific plural forms** (e.g., Malayalam: വാക്യം vs വാക്യങ്ങൾ)
- ✅ **Fallback handling** for missing translations
- ✅ **Type-safe** translation keys with TypeScript
- ✅ **Zero dependencies** - pure TypeScript implementation

## Quick Start

### 1. Import and Initialize

```typescript
import { i18n } from '../_shared/services/i18n-service.ts'
import { loadAllLocales } from '../_shared/locales/index.ts'

// Load all translations (call once at module initialization)
loadAllLocales()
```

### 2. Use Translations

```typescript
// Simple translation
const title = i18n.t('notification.memoryVerse.title', { locale: 'en' })
// Returns: '📚 Review Time'

// Pluralized translation (English)
const body = i18n.t('notification.memoryVerse.reminder', {
  locale: 'en',
  count: 1
})
// Returns: '1 verse due today for review'

const body2 = i18n.t('notification.memoryVerse.reminder', {
  locale: 'en',
  count: 5
})
// Returns: '5 verses due today for review'

// Pluralized translation (Malayalam)
const bodyMl = i18n.t('notification.memoryVerse.reminder', {
  locale: 'ml',
  count: 1
})
// Returns: '1 വാക്യം ഇന്ന് ഓർമ്മിക്കാൻ' (singular: വാക്യം)

const bodyMl2 = i18n.t('notification.memoryVerse.reminder', {
  locale: 'ml',
  count: 5
})
// Returns: '5 വാക്യങ്ങൾ ഇന്ന് ഓർമ്മിക്കാൻ' (plural: വാക്യങ്ങൾ)
```

## Supported Languages

| Language | Code | Singular Example | Plural Example |
|----------|------|------------------|----------------|
| English | `en` | 1 verse | 5 verses |
| Hindi | `hi` | 1 वचन | 5 वचन |
| Malayalam | `ml` | 1 വാക്യം | 5 വാക്യങ്ങൾ |

## Translation File Structure

### Locale Files (`en.ts`, `hi.ts`, `ml.ts`)

```typescript
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
    },
  },
}
```

### Key Structure

- **Simple strings**: Use `{ simple: 'Text' }`
- **Pluralized strings**: Use `{ plural: { one: '...', other: '...', zero: '...' } }`
- **Nested keys**: Use dot notation (e.g., `notification.memoryVerse.title`)

## Pluralization Rules

### English (`en`)
- `count === 0` → `zero` (if defined) or `other`
- `count === 1` → `one`
- `count !== 1` → `other`

### Hindi (`hi`)
- Same rule as English
- Note: Hindi often uses the same word form for singular/plural (वचन), but context may differ

### Malayalam (`ml`)
- Same rule as English
- **Important**: Malayalam has distinct plural forms with suffixes:
  - Singular: വാക്യം (vākyaṁ)
  - Plural: വാക്യങ്ങൾ (vākyaṅṅaḷ) - adds ങ്ങൾ suffix

## Adding New Translations

### 1. Add to Locale Files

Add your translation to all three locale files (`en.ts`, `hi.ts`, `ml.ts`):

```typescript
// en.ts
export const en: LocaleMessages = {
  notification: {
    newFeature: {
      title: {
        simple: '🎉 New Feature',
      },
      message: {
        plural: {
          one: '{{count}} new update available',
          other: '{{count}} new updates available',
        },
      },
    },
  },
}

// hi.ts - Work with native speakers for accurate translations
export const hi: LocaleMessages = {
  notification: {
    newFeature: {
      title: {
        simple: '🎉 नई सुविधा',
      },
      message: {
        plural: {
          one: '{{count}} नया अपडेट उपलब्ध है',
          other: '{{count}} नए अपडेट उपलब्ध हैं',
        },
      },
    },
  },
}

// ml.ts - Work with native speakers for accurate translations
export const ml: LocaleMessages = {
  notification: {
    newFeature: {
      title: {
        simple: '🎉 പുതിയ സവിശേഷത',
      },
      message: {
        plural: {
          one: '{{count}} പുതിയ അപ്ഡേറ്റ് ലഭ്യമാണ്',
          other: '{{count}} പുതിയ അപ്ഡേറ്റുകൾ ലഭ്യമാണ്',
        },
      },
    },
  },
}
```

### 2. Use in Code

```typescript
const title = i18n.t('notification.newFeature.title', { locale })
const body = i18n.t('notification.newFeature.message', { locale, count })
```

## Fallback Handling

The i18n service includes automatic fallback handling:

```typescript
// Translation not found → returns key
i18n.t('missing.key') // Returns: 'missing.key'

// Locale not supported → falls back to 'en'
const locale = 'fr' // Not supported
const normalizedLocale = (['en', 'hi', 'ml'].includes(locale) ? locale : 'en')

// Manual fallback pattern (recommended for critical notifications)
const title = i18n.t('notification.title', { locale })
const finalTitle = title.startsWith('notification.')
  ? i18n.t('notification.title', { locale: 'en' })
  : title
```

## Best Practices

### ✅ DO
- Always provide translations for all three languages (en, hi, ml)
- Work with native speakers for Hindi and Malayalam translations
- Use the `count` parameter for pluralized strings
- Handle missing translation fallbacks for critical features
- Use descriptive translation keys (e.g., `notification.memoryVerse.reminder`)

### ❌ DON'T
- Don't apply English pluralization rules to Hindi/Malayalam
- Don't hardcode translations in notification functions
- Don't skip the `count` parameter for pluralized translations
- Don't use generic keys like `message1`, `text2`

## Example: Memory Verse Notifications

### ❌ Before (Incorrect - English rules applied to all languages)

```typescript
const REMINDER_BODIES: Record<string, (count: number) => string> = {
  en: (count) => `${count} verse${count === 1 ? '' : 's'} due today`,
  hi: (count) => `${count} वचन आज याद करने के लिए`, // Missing plural logic
  ml: (count) => `${count} വാക്യം ഇന്ന് ഓർമ്മിക്കാൻ`, // Wrong! Should use വാക്യങ്ങൾ for plural
}
```

### ✅ After (Correct - Proper i18n with pluralization)

```typescript
// Translations in locale files with proper plural forms
const title = i18n.t('notification.memoryVerse.title', { locale })
const body = i18n.t('notification.memoryVerse.reminder', {
  locale,
  count: dueVerseCount
})

// English: "5 verses due today for review"
// Hindi: "5 वचन आज याद करने के लिए"
// Malayalam: "5 വാക്യങ്ങൾ ഇന്ന് ഓർമ്മിക്കാൻ" ✅ Correct plural form!
```

## Testing

Run tests to verify pluralization:

```bash
cd backend/supabase/functions/_shared/services
deno test i18n-service.test.ts
```

## Malayalam Plural Forms Reference

| Singular | Plural | Meaning |
|----------|--------|---------|
| വാക്യം | വാക്യങ്ങൾ | verse(s) |
| പുസ്തകം | പുസ്തകങ്ങൾ | book(s) |
| ദിവസം | ദിവസങ്ങൾ | day(s) |
| സുഹൃത്ത് | സുഹൃത്തുക്കൾ | friend(s) |

**Pattern**: Many Malayalam nouns add **ങ്ങൾ** (ṅṅaḷ) or **ുക്കൾ** (ukkaḷ) for plural.

## Resources

- [i18n Service Source](../services/i18n-service.ts)
- [Test Suite](../services/i18n-service.test.ts)
- [English Translations](./en.ts)
- [Hindi Translations](./hi.ts)
- [Malayalam Translations](./ml.ts)

## Support

For translation updates or issues:
1. Consult with native speakers for Hindi/Malayalam
2. Verify pluralization rules for the target language
3. Test with actual count values (0, 1, 2, 5, 10)
4. Update all three locale files simultaneously
