# Restoring static rendering on the marketing site

**Date:** 2026-09-07 · **Status:** Planned, awaiting execution
**Problem:** every route renders per request, costing ~95ms CPU each (4h Fluid Active CPU across 151K requests in 30 days, at the 4h allowance).

## Root cause, established by experiment

1. `app/layout.tsx` calls `getLocale()` from `next-intl/server`. It is the root layout, so this request-scoped call sits above **every** route and forces all of them dynamic.
2. `unstable_setRequestLocale` is called nowhere. next-intl v3 requires it in each layout and page that should render statically; `generateStaticParams` alone is not enough.

Both must change together. Removing only the first was tried and changed nothing.

**Evidence:** the build reports `✓ Generating static pages (84/84)` but writes no prerendered artifacts; `prerender-manifest.json` lists only robots/sitemap/favicon; every route responds `Cache-Control: private, no-cache, no-store`.

**Ruled out:** CDN cache headers. Adding `s-maxage` via `next.config.mjs` `headers()` was tested — Next's own `no-store` wins on dynamic routes, response unchanged. Reverted.

## Two findings that make the fix smaller than feared

**The non-locale duplicate routes are redundant.** `app/blog`, `app/paths`, `app/about`, `app/pricing`, `app/privacy`, `app/refund`, `app/terms`, `app/contact`, `app/download`, `app/page.tsx`, `app/features/*`, `app/vs/*` all duplicate a `[locale]` twin. Proven by removing `app/paths` and `app/blog` entirely and rebuilding: `/paths`, `/blog`, `/blog/<slug>`, `/blog?q=jesus` and `/hi/blog` all still returned 200 and rendered correctly, because middleware rewrites them into the locale segment. `/links` is the sole exception with no twin and must stay.

**Multiple root layouts remove the lang/static trade-off.** Route groups may each own a root layout, so the locale segment can render `<html lang={locale}>` itself while `/links` keeps its own. Nothing request-scoped needs to sit above every route, and the language attribute stays correct in all three languages.

## Target structure

```
app/
  (site)/[locale]/layout.tsx     root layout for locale routes; renders <html lang={locale}>,
                                 calls unstable_setRequestLocale, provides NextIntlClientProvider
  (site)/[locale]/**             existing locale pages, each calling unstable_setRequestLocale
  (standalone)/links/layout.tsx  own root layout (English only, no intl needed)
  (standalone)/links/page.tsx
  og/route.tsx, robots.ts, sitemap.ts, globals.css, favicon.ico   unchanged
```
`app/layout.tsx` and every non-locale duplicate page are deleted.

## Steps, each verified before the next

1. Delete the redundant non-locale duplicates. Build, confirm every URL still resolves.
2. Introduce the route groups and move `<html>`/`<body>` into the locale root layout; delete `app/layout.tsx`. Preserve exactly what the current root layout renders: font variables, `suppressHydrationWarning`, ThemeProvider, Analytics, SpeedInsights, NavigationProgress, JSON-LD, and all metadata including `metadataBase`, alternates, OpenGraph, Twitter and icons.
3. Add `unstable_setRequestLocale(locale)` to the locale layout and to every locale page expected to be static.
4. Leave the blog/tag/search LIST pages dynamic — they read `searchParams` and cannot be static. The post pages, paths pages and all the marketing pages are the target.

## Definition of done

Not a route table that merely looks different — that is what misled us before.

- `next build` writes real `.html`/`.rsc` files under `.next/server/app/` for `/en`, `/hi`, `/ml` and the static pages.
- `prerender-manifest.json` lists those routes.
- A production server returns a cache hit rather than `no-store` on a static route.
- **`vercel build` output inspected**: `.vercel/output/config.json` and the `functions/` directory show the static pages as static assets, not lambdas. This is the closest local mirror of what Vercel actually deploys and is the real acceptance test.

## Regression checks (headless browser, production build)

`/`, `/hi`, `/ml` render with correct `lang` and localised copy · a blog post in all three locales renders real body text · unknown slug still 404s · blog list still works with `?q=`, `?tag=`, `?page=2` including a Devanagari query · both paths pages · `/links` at its path and via `Host: links.disciplefy.in` · `/og?title=Test` returns a PNG, plus the Indic fallback · sitemap and robots unchanged · no new console errors.

Known pre-existing and out of scope: `components/layout/Navbar.tsx:20` double-prefixes the locale, so prefetches hit `/hi/hi/download`.

## Risk

This touches every route on the marketing site. It is reversible (nothing committed, and the tree is recoverable from `origin/dev`), but it must be done stepwise with a build between each step, not as one sweeping edit. A previous attempt at this bisected by moving the whole `app/` directory into scratch folders and had to be reverted.
