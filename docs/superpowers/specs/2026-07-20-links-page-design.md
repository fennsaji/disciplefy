# Link-in-Bio Page — Design

Date: 2026-07-20
Status: Approved

## Problem

Instagram, YouTube, and Facebook bios allow one link. Disciplefy has several destinations worth sending people to — the Android app, the web app, four social channels, and a support address — with no single page collecting them.

Today the bio link points at `disciplefy.in`, which is a full marketing site: slow to scan on a phone, and it buries the install CTA below hero and feature sections.

## Goal

A single, phone-first page at `links.disciplefy.in` listing every Disciplefy destination, optimised for a visitor who arrived from a social bio tap and will decide within seconds.

## Decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Location | `/links` route inside the existing `marketing/` Next.js app | Reuses the deploy pipeline, fonts, and Vercel Analytics. No second project, no duplicated theme config. |
| URL | `links.disciplefy.in`, via host rewrite | Short and memorable in a bio. Also reachable at `disciplefy.in/links`. |
| Theme | Dark only | Chosen from mockups. Every visitor sees the approved design regardless of their stored theme preference. |
| Language | English only | Link labels are mostly proper nouns. Avoids three message-file entries for ~8 strings. |
| Layout | Full-width vertical stack, grouped into three labelled sections | Familiar Linktree pattern; largest tap targets. |
| Icons | Inline SVG | No icon font, no network request, no runtime dependency. |

Rejected: a separate Vercel project (duplicated Tailwind/font config, second CI workflow); Linktree itself (no brand control, no analytics); a static HTML file (drifts from brand as the site evolves).

## Page Content

Header: `logo-dark.png` wordmark, then the tagline "AI-powered Bible study guides / English · हिन्दी · മലയാളം".

**Get the app**
| Label | Destination | State |
|---|---|---|
| Download for Android | `PLAY_STORE_URL` | Primary CTA — gold gradient |
| Download for iOS | — | Disabled, "SOON" pill |
| Use in your browser | `WEB_APP_URL` | Standard row |

**Follow along**
| Label | Destination |
|---|---|
| Instagram | `https://www.instagram.com/disciplefy.in` |
| YouTube | `https://www.youtube.com/@disciplefy` |
| WhatsApp Community | `https://chat.whatsapp.com/DUSZ19PqTnnEDC4adHPNfh?mode=gi_t` |
| Facebook | `https://facebook.com/disciplefy` |

**Say hello**
| Label | Destination |
|---|---|
| hello@disciplefy.in | `mailto:` |

Footer: `disciplefy.in` linking to the main site.

Android is the primary CTA because it is the only store currently live. When iOS ships, iOS and Android become equal-weight rows and the gold treatment moves to whichever the visitor's device matches, or to neither — a follow-up decision, out of scope here.

## Architecture

### Shared link constants

`components/layout/Footer.tsx:36-39` and `app/contact/page.tsx:45-60` each hard-code the same four social URLs. The links page would be a third copy.

Extract to `lib/social-links.ts` as the single source of truth, exporting the URL list and the four brand SVG components currently defined inline at `Footer.tsx:8-30`. Footer, contact page, and the links page all import from it. This is the only change to existing files beyond middleware, and it removes duplication rather than adding it.

Store and web URLs already have a single source at `lib/app-links.ts` — reuse as-is. The iOS URL is added there when it exists, and the links page reads it; no other file changes when iOS ships.

### Route

`app/links/page.tsx` — a server component, English only, so it needs no `NextIntlClientProvider`. It renders standalone: no Navbar, no Footer.

No `app/[locale]/links/page.tsx`. `/hi/links` and `/ml/links` correctly 404.

### Dark-only styling

`app/layout.tsx:62-67` wraps everything in `ThemeProvider` with `defaultTheme="system"` and a persisted `disciplefy-theme` key. A visitor with a stored light preference would otherwise see a light `/links`.

The page therefore uses explicit colour classes (`bg-[#0F172A]`, `text-slate-100`) rather than `dark:` variants, making it independent of the `html.dark` class. No change to the root layout, no `forcedTheme`, no effect on any other route.

### Host rewrite

`middleware.ts` currently exports `createMiddleware` from next-intl directly. Wrap it:

```ts
export default function middleware(req: NextRequest) {
  const host = req.headers.get("host") ?? "";
  if (host.startsWith("links.") && req.nextUrl.pathname === "/") {
    return NextResponse.rewrite(new URL("/links", req.url));
  }
  return intlMiddleware(req);
}
```

The host check runs before the intl middleware, so next-intl never sees the subdomain root and cannot apply locale handling to it.

Considered and rejected: a `has: [{ type: "host" }]` rewrite in `next.config.mjs`, matching the existing `policies.disciplefy.in` redirects at `next.config.mjs:14-41`. Rejected because config rewrites and middleware have a defined but subtle ordering relationship, and next-intl's middleware would process the request first. Doing the check inside middleware keeps the order explicit.

Any path other than `/` on the subdomain falls through to the intl middleware and resolves normally, so `links.disciplefy.in/privacy` still works.

### SEO

Two URLs serve identical content. Set `alternates.canonical` to `https://links.disciplefy.in/` on the route so `disciplefy.in/links` does not compete in the index.

Not added to `app/sitemap.ts` — it is a social redirect surface, not content to rank. `app/robots.ts` needs no change; the existing `*` rule already allows it.

### Infrastructure

1. Vercel → marketing project → Domains → add `links.disciplefy.in`
2. DNS → `CNAME links → cname.vercel-dns.com`
3. Certificate issues automatically

`vercel.json:12` already sets HSTS with `includeSubDomains; preload`, which covers the new subdomain — it must serve HTTPS from first request, which Vercel does.

## Out of Scope

- Hindi and Malayalam versions
- Click analytics beyond the existing Vercel Analytics page views
- A CMS or admin UI for editing links — the list is a typed constant, edited in code
- Content page links (blog, paths, features) — deliberately excluded to keep the page short
- Changing which link the Instagram bio actually points at — a manual step after deploy

## Verification

- `npm run build` in `marketing/` passes
- `npm run dev`, visit `localhost:10200/links` — renders dark regardless of the `disciplefy-theme` value in localStorage
- Every link opens the correct destination; iOS row is inert and not focusable
- Footer and contact page still render their social links correctly after the constant extraction
- On the Vercel preview, `curl -H "Host: links.disciplefy.in" <preview-url>/` returns the links page
- Page is legible at 320px width with no horizontal scroll

## Open Items

- **iOS App Store URL** — does not exist; the app is in review. The disabled row ships as designed. When the URL lands, add `APP_STORE_URL` to `lib/app-links.ts` and the row activates.
