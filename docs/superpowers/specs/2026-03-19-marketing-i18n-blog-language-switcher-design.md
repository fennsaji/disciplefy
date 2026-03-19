# Marketing i18n + Blog Language Switcher — Design Spec

## Goal

Translate all static content on the marketing site's Pricing, About, and Blog pages for Hindi and Malayalam, and add a language switcher to the blog filters so users can switch between EN/HI/ML posts without navigating away.

## Architecture

The marketing site uses next-intl with `localePrefix: "as-needed"`. Message files (`en.json`, `hi.json`, `ml.json`) already exist with many translated keys. The core problem is twofold: (1) `[locale]/pricing` and `[locale]/about` re-export the English base page instead of loading locale-specific messages; (2) `PricingPageContent` and `AboutPageContent` have all content hardcoded — they don't use `useTranslations()` at all.

The `[locale]/layout.tsx` already loads messages and wraps all children in `NextIntlClientProvider`. This means every route under `[locale]/` already has the correct locale context. The fix is simply to make `[locale]/pricing` and `[locale]/about` render their components directly — matching the pattern of `[locale]/page.tsx` — instead of re-exporting the English base page.

## Tech Stack

- **next-intl v3** — `useTranslations()`, `useLocale()`, `NextIntlClientProvider` (provided by layout)
- **Next.js 14 App Router** — server components for pages, client components for interactive UI
- **framer-motion** — used in `PricingPageContent` and `AboutPageContent` (must stay `"use client"`)

---

## Component & File Map

### Files to modify:
- `marketing/app/[locale]/pricing/page.tsx` — replace re-export with direct component render
- `marketing/app/[locale]/about/page.tsx` — replace re-export with direct component render
- `marketing/components/sections/PricingPageContent.tsx` — use `useTranslations('pricingPage')`
- `marketing/components/sections/AboutPageContent.tsx` — use `useTranslations('about')`
- `marketing/components/blog/BlogFilters.tsx` — add language switcher pills; accept `locale` prop
- `marketing/app/[locale]/blog/page.tsx` — pass `locale` prop to `BlogList`
- `marketing/app/blog/page.tsx` — pass `locale="en"` prop to `BlogList`
- `marketing/components/blog/BlogList.tsx` — thread `locale` prop down to `BlogFilters`
- `marketing/messages/en.json` — add new keys (merge into existing objects)
- `marketing/messages/hi.json` — add Hindi translations for new keys
- `marketing/messages/ml.json` — add Malayalam translations for new keys

### Files unchanged:
- `marketing/app/pricing/page.tsx` — English base page stays as-is
- `marketing/app/about/page.tsx` — English base page stays as-is
- `marketing/app/blog/[slug]/page.tsx` — already updated with `force-dynamic`

---

## Section 1: Fix Locale Pages

### `app/[locale]/pricing/page.tsx`

The `[locale]/layout.tsx` already provides `NextIntlClientProvider` with the correct locale and messages. The locale page just needs to render the component — matching the pattern of `[locale]/page.tsx`:

```tsx
// marketing/app/[locale]/pricing/page.tsx
import { PricingPageContent } from "@/components/sections/PricingPageContent";
import { pricingJsonLd } from "@/lib/seo";

export { metadata } from "@/app/pricing/page"; // reuse EN metadata for now

export default function LocalePricingPage() {
  return <PricingPageContent jsonLd={JSON.stringify(pricingJsonLd)} />;
}
```

Locale-aware metadata (translating the page title/description) is **out of scope** for this task — the existing English metadata is acceptable for all locales.

### `app/[locale]/about/page.tsx`

Same pattern:

```tsx
// marketing/app/[locale]/about/page.tsx
import { AboutPageContent } from "@/components/sections/AboutPageContent";

export { metadata } from "@/app/about/page";

export default function LocaleAboutPage() {
  return <AboutPageContent />;
}
```

---

## Section 2: New Translation Keys

Keys are **merged** into existing objects — they must not replace them. All three message files (`en.json`, `hi.json`, `ml.json`) must have the following additions.

### Pricing — use namespace `"pricingPage"` (not `"pricing"`)

> ⚠️ The existing `"pricing"` namespace is used by the homepage pricing strip. To avoid conflicts (e.g., `perMonth: "/month"` vs `"/mo"`), all new pricing page keys live under `"pricingPage"`.

```json
{
  "pricingPage": {
    "pageTitle": "Simple, Affordable Plans",
    "pageSubtitle": "Start free. Upgrade when you need more.",
    "faqTitle": "Frequently Asked Questions",
    "ctaText": "Ready to start your Bible study journey?",
    "startFreeNoCard": "Start Free — No Credit Card Required",
    "getStarted": "Get Started",
    "startFree": "Start Free",
    "mostPopular": "Most Popular",
    "perMonth": "/mo",
    "plans": [
      {
        "name": "Free",
        "price": 0,
        "tokens": "8 tokens/day",
        "popular": false,
        "features": [
          "Quick Read study guide mode",
          "3 memory verses",
          "2 practice modes",
          "1 practice per verse/day",
          "Token top-ups available",
          "Daily verse"
        ]
      },
      {
        "name": "Standard",
        "price": 79,
        "tokens": "20 tokens/day",
        "popular": false,
        "features": [
          "All study guide modes",
          "5 follow-up questions/day",
          "3 AI Discipler calls/month",
          "5 memory verses",
          "2 practices per verse/day",
          "Token top-ups available"
        ]
      },
      {
        "name": "Plus",
        "price": 149,
        "tokens": "50 tokens/day",
        "popular": true,
        "features": [
          "All study guide modes",
          "10 follow-up questions/day",
          "10 AI Discipler calls/month",
          "10 memory verses",
          "3 practices per verse/day",
          "Token top-ups available"
        ]
      },
      {
        "name": "Premium",
        "price": 499,
        "tokens": "Unlimited tokens",
        "popular": false,
        "features": [
          "All study guide modes",
          "Unlimited follow-up questions",
          "Unlimited AI Discipler calls",
          "Unlimited memory verses",
          "Unlimited practice",
          "Priority support"
        ]
      }
    ],
    "faqs": [
      {
        "q": "What is a token?",
        "a": "Tokens are the currency for AI features in Disciplefy. Each study guide, follow-up, or AI Discipler call uses a small number of tokens. Your plan resets your token count daily."
      },
      {
        "q": "Can I switch plans?",
        "a": "Yes, you can upgrade or downgrade at any time. Changes take effect at the start of your next billing cycle."
      },
      {
        "q": "How does payment work?",
        "a": "Payments are processed securely via Razorpay. We accept UPI, debit/credit cards, and net banking."
      },
      {
        "q": "Is my data safe?",
        "a": "Yes. We use Supabase Auth and follow India's DPDP 2023 guidelines. We never sell your data."
      },
      {
        "q": "What languages are supported?",
        "a": "English, Hindi, and Malayalam. All AI features including study guides and Voice Buddy work in all three languages."
      }
    ]
  }
}
```

### About — new `"about"` namespace

```json
{
  "about": {
    "title": "About Disciplefy",
    "mission": {
      "title": "Our Mission",
      "content": "We believe every believer deserves to understand God's Word in their heart language. Disciplefy exists to make deep, meaningful Bible study accessible to every Indian Christian — in English, Hindi, and Malayalam."
    },
    "vision": {
      "title": "Our Vision",
      "content": "To enable every Indian Christian to study Scripture deeply, daily, in the language they think and pray in. We envision a generation of believers who are rooted in God's Word and equipped to live it out in their communities."
    },
    "theology": {
      "title": "Theological Stance",
      "p1": "Disciplefy is built on orthodox Protestant Christian theology. All content is reviewed for doctrinal accuracy and follows historical-grammatical interpretation of Scripture. We hold to the foundational truths of the Christian faith as expressed in historic creeds.",
      "p2": "We do not replace the local church or its leadership. Disciplefy is a tool to complement your church community, Sunday school, and personal devotional life — not to substitute them."
    },
    "technology": {
      "title": "The Technology",
      "content": "Disciplefy uses AI to generate Bible study content — summaries, context, interpretation, prayer points, and discussion questions. The AI follows strict theological guidelines and all output is constrained to align with orthodox Christian teaching. The AI assists study; it does not interpret Scripture with authority. That authority belongs to Scripture alone."
    },
    "contact": {
      "title": "Contact Us",
      "text": "Questions, partnerships, or feedback:"
    }
  }
}
```

### Blog — merge into existing `"blog"` namespace

> ⚠️ Merge these keys into the existing `"blog"` object — do not replace it.

```json
{
  "blog": {
    "searchPlaceholder": "Search articles…",
    "allTag": "All"
  }
}
```

Note: Language pill labels (`English`, `हिन्दी`, `മലയാളം`) are **not** added to the message files — `BlogFilters` uses a hardcoded constant map to avoid a `useTranslations` provider dependency on the English base route.

---

## Section 3: Update Components

### `PricingPageContent.tsx`

- Import `useTranslations` from `"next-intl"`
- Use `useTranslations('pricingPage')`
- Replace hardcoded `plans` and `faqs` arrays with `t.raw('plans')` and `t.raw('faqs')`
- `t.raw()` returns `unknown` — cast with `as Array<PricingPlan>` and `as Array<FAQ>` where the types are locally defined interfaces
- Plan `price` and `popular` are now included in the JSON (see Section 2), so no separate local constant is needed
- Replace all hardcoded string literals: `t('pageTitle')`, `t('faqTitle')`, `t('startFreeNoCard')`, `t('perMonth')`, `t('mostPopular')`, `t('ctaText')`, `t('getStarted')`, `t('startFree')`
- Button label: `plan.price === 0 ? t('startFree') : t('getStarted')`

### `AboutPageContent.tsx`

- Import `useTranslations` from `"next-intl"`
- Use `useTranslations('about')`
- Replace hardcoded `sections` array with individual translation calls
- **Important:** Remove the `section.title === "Our Mission"` string comparison for conditional styling. Use index-based check (`index === 0`) or a dedicated flag instead, since translated titles will not match the English string.

### `BlogFilters.tsx`

`BlogFilters` is rendered from both `app/blog/page.tsx` (English base, outside `[locale]/`) and `app/[locale]/blog/page.tsx`. The English base page is outside the `[locale]/layout.tsx` provider tree, so `useLocale()` cannot be used safely — it may return the default locale or throw depending on context.

**Solution:** Pass `locale` as an explicit prop from the page through `BlogList` down to `BlogFilters`. This is always available as a string at the page level.

```tsx
// BlogFilters receives:
interface BlogFiltersProps {
  tags: string[];
  activeTag?: string;
  query?: string;
  locale: string;  // NEW
}
```

Language switcher implementation:

```tsx
const localeBasePaths: Record<string, string> = {
  en: "/blog",
  hi: "/hi/blog",
  ml: "/ml/blog",
};

// Language pill click handler:
const switchLocale = (newLocale: string) => {
  const params = new URLSearchParams(searchParams.toString());
  params.delete("page");
  const base = localeBasePaths[newLocale] ?? "/blog";
  startTransition(() => router.push(`${base}?${params.toString()}`));
};
```

Language pills rendered above the tag pills. **Do not use `useTranslations` in `BlogFilters`** — `app/blog/page.tsx` (the English base route) is outside `[locale]/layout.tsx` and has no `NextIntlClientProvider`, so `useTranslations` would throw at runtime. Instead, derive labels from a simple constant map (no provider needed):

```tsx
const LOCALE_LABELS: Record<string, string> = {
  en: "English",
  hi: "हिन्दी",
  ml: "മലയാളം",
};
```

This also means `"langEn"`, `"langHi"`, `"langMl"` keys do **not** need to be added to the message files.

### `BlogList.tsx`

Accept and thread the `locale` prop:

```tsx
// Add to BlogList props:
locale: string;

// Pass down to BlogFilters:
<BlogFilters ... locale={locale} />
```

### Callers of `BlogList`

- `app/blog/page.tsx` — add `locale="en"` prop
- `app/[locale]/blog/page.tsx` — add `locale={params.locale}` prop

---

## Data Flow

```
User visits /hi/blog
  → [locale]/layout.tsx provides NextIntlClientProvider locale="hi"
  → [locale]/blog/page.tsx (force-dynamic) → getAllPosts("hi")
  → BlogList locale="hi" → BlogFilters locale="hi"
  → Language pills: [English] [हिन्दी ✓] [മലയാളം]
  → useTranslations('blog') reads from hi.json

User clicks "English" pill in BlogFilters
  → router.push("/blog?tag=...")
  → app/blog/page.tsx serves EN posts

User visits /hi/pricing
  → [locale]/layout.tsx provides NextIntlClientProvider locale="hi"
  → [locale]/pricing/page.tsx renders <PricingPageContent />
  → useTranslations('pricingPage') reads from hi.json
  → All plan names, features, FAQ rendered in Hindi
```

---

## Error Handling

- `t.raw()` returns `unknown` — use locally defined TypeScript interfaces and `as` casts. Define `PricingPlan` and `FAQ` interfaces in `PricingPageContent.tsx`.
- Missing translation keys: next-intl logs a warning in development and falls back to the key name — acceptable during initial rollout while translations are being filled in.
- The `localeBasePaths` map in `BlogFilters` covers all three locales explicitly — no unknown locale can be passed since `Locale` type is `"en" | "hi" | "ml"`.

---

## Out of Scope

- Locale-aware `<head>` metadata (page title/description) for pricing and about pages — English metadata is reused for all locales
- Feature pages (`[locale]/features/*`) — already use `useTranslations` where needed
- Legal pages (privacy, terms, refund) — English-only is acceptable
- Blog post content — dynamically generated per locale by the cron, not static
