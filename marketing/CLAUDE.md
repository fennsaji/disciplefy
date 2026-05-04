# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Marketing website for Disciplefy (www.disciplefy.in) — a Next.js 14 App Router site with i18n support for English, Hindi, and Malayalam. Deployed on Vercel.

## Commands

```bash
npm run dev      # Dev server at localhost:10200
npm run build    # Production build
npm run lint     # ESLint (next lint)
npm start        # Production server at localhost:10200
```

No test framework is configured.

## Environment

Copy `.env.example` to `.env.local`. The only variable is `NEXT_PUBLIC_APP_URL` (defaults to `https://app.disciplefy.in`). Blog posts are fetched from `BLOG_API_URL` (defaults to `http://localhost:8080`).

## Architecture

### Routing & i18n

- **next-intl** handles locale routing via `middleware.ts` and `i18n.ts`
- Locale prefix strategy: `"as-needed"` — English at `/`, Hindi at `/hi`, Malayalam at `/ml`
- No Accept-Language auto-detection; URL locale always wins
- All routes live under `app/[locale]/` — the `[locale]/layout.tsx` wraps children with `NextIntlClientProvider`
- Translation files: `messages/{en,hi,ml}.json`
- **Always use `@/lib/navigation.ts` exports** (`Link`, `redirect`, `usePathname`, `useRouter`) instead of `next/navigation` — these are locale-aware wrappers

### Component Organization

- `components/ui/` — Reusable building blocks (Button, ThemeToggle, LocaleSwitcher, AppStoreBadges, CookieConsent, NavigationProgress)
- `components/sections/` — Page section components (Hero, Features, HowItWorks, Pricing, Testimonials, etc.)
- Pages are composed by importing section components

### Styling

- **Tailwind CSS** with CSS variable design tokens defined in `app/globals.css`
- Light/dark themes via `next-themes` (class-based, stored as `disciplefy-theme` in localStorage)
- Custom colors in `tailwind.config.ts`: `primary`, `dark.*`, `light.*`, `accent`, `gold`, `coral`
- Fonts: Inter (body), Poppins (display/headings), Noto Sans Devanagari (Hindi), Noto Sans Malayalam — configured in `lib/fonts.ts`
- Hindi/Malayalam fonts are lazy-loaded (`preload: false`) to avoid blocking English users
- MDX prose styling via `.prose-disciplefy` class in globals.css

### Performance Considerations

- Hero H1 **must never start at `opacity: 0`** — this delays LCP. Use `animate-hero-headline` (transform-only) for H1; opacity animations are only for supporting elements
- Hero animations are CSS-only (`globals.css`), not framer-motion, to avoid JS overhead
- `@media (prefers-reduced-motion: reduce)` disables all hero animations

### Content

- Legal pages (privacy, terms, refund) use MDX files in `content/{privacy,terms,refund}/en.mdx`
- Blog posts are fetched from an external API (`BLOG_API_URL`) via `lib/blog.ts` with retry logic
- OG images are generated dynamically at `/og/route.tsx`
- SEO utilities (alternates, JSON-LD) in `lib/seo.ts`

### Key Files

- `lib/app-links.ts` — Single source of truth for Play Store URL and web app URL
- `lib/plans.ts` — Pricing plan definitions
- `lib/blog.ts` — Blog API client with retry and `cache()` deduplication
- `app/robots.ts` / `app/sitemap.ts` — Auto-generated SEO files
- `next.config.mjs` — MDX plugin, next-intl plugin, image optimization, policy subdomain redirects

## Commit Convention

Format: `type(scope): brief description` (one-liner only). Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`. Do **not** add `Co-Authored-By` lines.
