# Link-in-Bio Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a dark, phone-first link-in-bio page at `links.disciplefy.in` listing every Disciplefy destination.

**Architecture:** A new `/links` route inside the existing `marketing/` Next.js 14 App Router app. `middleware.ts` rewrites the subdomain root to that route before next-intl sees the request. The four social URLs — currently duplicated in two files — are extracted to a shared module that all three consumers import.

**Tech Stack:** Next.js 14 (App Router), React 18, TypeScript, Tailwind CSS, next-intl, Vercel.

## Global Constraints

- Work only inside `/Users/fennsaji/Documents/Projects/Fenn/bible-study-app/marketing`. Run all commands from that directory.
- **No test framework is configured in this project** (`marketing/CLAUDE.md`). There is no `npm test`. Each task's verification gate is `npm run lint` + `npm run build` + a stated manual browser check. Do not add a test framework — it is out of scope for this plan.
- Dev server runs on port **10200**, not 3000.
- The links page is **dark only**. Use explicit colour classes (`bg-[#0F172A]`), never `dark:` variants — the page must not depend on the `html.dark` class that `app/layout.tsx:62-67` controls.
- The links page is **English only**. Do not add entries to `messages/*.json`. Do not create `app/[locale]/links/`.
- Import locale-aware `Link` from `@/lib/navigation` only where locale matters. The links page uses plain `<a>` for external URLs.
- Commit messages: `type(scope): brief description`, one line. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`. **Never** add `Co-Authored-By` lines.
- Exact brand colours: gold `#D4930A`, gold-dark `#B87C05`, gold-tint `#F3C766`, dark bg `#0F172A`, dark surface `#1E293B`, muted `#94A3B8`, dim `#64748B`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/social-links.tsx` | **Create.** Single source of truth for the four social URLs and their brand SVG icons. |
| `lib/app-links.ts` | **Modify.** Add `APP_STORE_URL`, null until iOS clears review. |
| `components/links/PlatformIcons.tsx` | **Create.** Android, Apple, globe, and mail SVGs — used only by the links page. |
| `components/links/LinkRow.tsx` | **Create.** The row primitive: default, primary, and disabled variants. |
| `app/links/page.tsx` | **Create.** Composes the page. |
| `components/layout/Footer.tsx` | **Modify.** Import from `lib/social-links` instead of defining icons and URLs inline. |
| `app/contact/page.tsx` | **Modify.** Same. |
| `middleware.ts` | **Modify.** Host check before the next-intl middleware. |

---

### Task 1: Extract shared social links

Three files would otherwise hard-code the same four URLs. This task creates the shared module and repoints the two existing consumers. No visual change — the Footer and contact page must render exactly as before.

**Files:**
- Create: `lib/social-links.tsx`
- Modify: `components/layout/Footer.tsx:8-40`
- Modify: `app/contact/page.tsx:42-68`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `SOCIAL: Record<"instagram"|"facebook"|"whatsapp"|"youtube", SocialLink>`
  - `SOCIAL_LINKS: SocialLink[]` — footer display order: Instagram, Facebook, WhatsApp, YouTube
  - `type SocialLink = { label: string; href: string; Icon: (props: { className?: string }) => JSX.Element }`

- [ ] **Step 1: Create the shared module**

The file must be `.tsx`, not `.ts` — it contains JSX.

```tsx
// marketing/lib/social-links.tsx
// Single source of truth for Disciplefy social channels.
// Consumed by the footer, the contact page, and the /links page.

type IconProps = { className?: string };

export const InstagramIcon = ({ className = "w-5 h-5" }: IconProps) => (
  <svg viewBox="0 0 24 24" fill="currentColor" className={className}>
    <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z" />
  </svg>
);

export const FacebookIcon = ({ className = "w-5 h-5" }: IconProps) => (
  <svg viewBox="0 0 24 24" fill="currentColor" className={className}>
    <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
  </svg>
);

export const WhatsAppIcon = ({ className = "w-5 h-5" }: IconProps) => (
  <svg viewBox="0 0 24 24" fill="currentColor" className={className}>
    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
  </svg>
);

export const YouTubeIcon = ({ className = "w-5 h-5" }: IconProps) => (
  <svg viewBox="0 0 24 24" fill="currentColor" className={className}>
    <path d="M23.498 6.186a3.016 3.016 0 00-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 00.502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 002.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 002.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z" />
  </svg>
);

export type SocialLink = {
  label: string;
  href: string;
  Icon: (props: IconProps) => JSX.Element;
};

export const SOCIAL = {
  instagram: {
    label: "Instagram",
    href: "https://www.instagram.com/disciplefy.in",
    Icon: InstagramIcon,
  },
  facebook: {
    label: "Facebook",
    href: "https://facebook.com/disciplefy",
    Icon: FacebookIcon,
  },
  whatsapp: {
    label: "WhatsApp",
    href: "https://chat.whatsapp.com/DUSZ19PqTnnEDC4adHPNfh?mode=gi_t",
    Icon: WhatsAppIcon,
  },
  youtube: {
    label: "YouTube",
    href: "https://www.youtube.com/@disciplefy",
    Icon: YouTubeIcon,
  },
} satisfies Record<string, SocialLink>;

/** Footer / contact display order. */
export const SOCIAL_LINKS: SocialLink[] = [
  SOCIAL.instagram,
  SOCIAL.facebook,
  SOCIAL.whatsapp,
  SOCIAL.youtube,
];
```

- [ ] **Step 2: Repoint the Footer**

Delete the four icon component definitions at `components/layout/Footer.tsx:8-30` and the `socials` array at lines 36-40 entirely. Add the import alongside the existing ones at the top of the file:

```tsx
import { SOCIAL_LINKS } from "@/lib/social-links";
```

Then replace the social render block. It currently reads:

```tsx
{socials.map((s) => (
  <a key={s.label} href={s.href} target="_blank" rel="noopener noreferrer" aria-label={s.label}
     className="text-[var(--muted)] hover:text-[var(--text)] hover:scale-110 transition-all">{s.icon}</a>
))}
```

Change to — note `s.icon` becomes `<s.Icon />`:

```tsx
{SOCIAL_LINKS.map((s) => (
  <a key={s.label} href={s.href} target="_blank" rel="noopener noreferrer" aria-label={s.label}
     className="text-[var(--muted)] hover:text-[var(--text)] hover:scale-110 transition-all"><s.Icon /></a>
))}
```

- [ ] **Step 3: Repoint the contact page**

Delete the entire `socials` array at `app/contact/page.tsx:42-68` (the one with inline `<svg>` elements — leave the `contacts` array above it alone). Add to the imports:

```tsx
import { SOCIAL_LINKS } from "@/lib/social-links";
```

In the "Follow Us" section, change `{socials.map((s) => (` to `{SOCIAL_LINKS.map((s) => (` and replace the `{s.icon}` expression in that block with `<s.Icon />`.

- [ ] **Step 4: Verify lint and build pass**

Run: `npm run lint && npm run build`
Expected: no errors. If TypeScript complains that `JSX` is not defined in `lib/social-links.tsx`, add `import type { JSX } from "react";` at the top.

- [ ] **Step 5: Verify no visual regression**

Run: `npm run dev`
Open `http://localhost:10200/` and `http://localhost:10200/contact`. The four social icons must render in both, identical to before, each linking to the correct destination. Confirm `/hi` and `/ml` footers still render too.

- [ ] **Step 6: Commit**

```bash
git add lib/social-links.tsx components/layout/Footer.tsx app/contact/page.tsx
git commit -m "refactor(marketing): extract social links to shared module"
```

---

### Task 2: Platform icons and the row primitive

Builds the two presentational pieces the page composes. Nothing is routable yet.

**Files:**
- Create: `components/links/PlatformIcons.tsx`
- Create: `components/links/LinkRow.tsx`
- Modify: `lib/app-links.ts`

**Interfaces:**
- Consumes: nothing from Task 1
- Produces:
  - `AndroidIcon`, `AppleIcon`, `GlobeIcon`, `MailIcon` — each `(props: { className?: string }) => JSX.Element`
  - `LinkRow` — props `{ label: string; href?: string; chipClass: string; icon: ReactNode; variant?: "default" | "primary"; badge?: string }`. Omitting `href` renders a non-interactive disabled row.
  - `APP_STORE_URL: string | null` from `lib/app-links.ts`

- [ ] **Step 1: Add the iOS constant**

Append to `lib/app-links.ts`:

```ts
/**
 * iOS App Store URL. Null until the app clears App Review — the /links page
 * renders a disabled "coming soon" row while this is null.
 */
export const APP_STORE_URL: string | null = null;
```

- [ ] **Step 2: Create the platform icons**

```tsx
// marketing/components/links/PlatformIcons.tsx
// Non-social icons used by the /links page.

type IconProps = { className?: string };

export const AndroidIcon = ({ className = "w-5 h-5" }: IconProps) => (
  <svg viewBox="0 0 24 24" fill="currentColor" className={className}>
    <path d="M17.6 9.48l1.84-3.18a.4.4 0 00-.7-.4l-1.86 3.22a11.5 11.5 0 00-9.76 0L5.26 5.9a.4.4 0 10-.7.4L6.4 9.48A10.8 10.8 0 001 18h22a10.8 10.8 0 00-5.4-8.52zM7 15.25a1.25 1.25 0 110-2.5 1.25 1.25 0 010 2.5zm10 0a1.25 1.25 0 110-2.5 1.25 1.25 0 010 2.5z" />
  </svg>
);

export const AppleIcon = ({ className = "w-5 h-5" }: IconProps) => (
  <svg viewBox="0 0 24 24" fill="currentColor" className={className}>
    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
  </svg>
);

export const GlobeIcon = ({ className = "w-5 h-5" }: IconProps) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" className={className}>
    <circle cx="12" cy="12" r="9.5" />
    <path d="M2.5 12h19M12 2.5a15 15 0 010 19 15 15 0 010-19z" />
  </svg>
);

export const MailIcon = ({ className = "w-5 h-5" }: IconProps) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round" className={className}>
    <rect x="2.5" y="4.5" width="19" height="15" rx="2.5" />
    <path d="M3 6.5l9 6.5 9-6.5" />
  </svg>
);
```

- [ ] **Step 3: Create the row primitive**

External links get `target="_blank"` and `rel="noopener noreferrer"`. The `mailto:` link must not, so the component checks the scheme. A row without `href` renders as a `<div>`, keeping it out of the tab order.

```tsx
// marketing/components/links/LinkRow.tsx
import type { ReactNode } from "react";

type LinkRowProps = {
  label: string;
  icon: ReactNode;
  /** Tailwind classes for the icon chip background. */
  chipClass: string;
  /** Omit to render a disabled, non-interactive row. */
  href?: string;
  variant?: "default" | "primary";
  /** Small pill on the right, e.g. "SOON". Only shown on disabled rows. */
  badge?: string;
};

const BASE =
  "flex items-center gap-3 rounded-2xl px-3.5 py-3 text-sm font-semibold tracking-tight";

const CHIP = "flex h-8 w-8 shrink-0 items-center justify-center rounded-[10px]";

export function LinkRow({ label, icon, chipClass, href, variant = "default", badge }: LinkRowProps) {
  const isPrimary = variant === "primary";

  const surface = isPrimary
    ? "bg-gradient-to-br from-[#D4930A] to-[#B87C05] text-white shadow-[0_6px_18px_rgba(212,147,10,0.38)] py-3.5 text-[15px] font-bold"
    : "bg-[#1E293B] border border-white/10 text-slate-100";

  const body = (
    <>
      <span className={`${CHIP} ${chipClass}`}>{icon}</span>
      <span>{label}</span>
      {badge ? (
        <span className="ml-auto rounded-full bg-white/[0.13] px-1.5 py-0.5 text-[9px] font-extrabold tracking-widest">
          {badge}
        </span>
      ) : (
        <span className={`ml-auto text-base font-normal ${isPrimary ? "opacity-70" : "opacity-30"}`} aria-hidden="true">
          ›
        </span>
      )}
    </>
  );

  if (!href) {
    return (
      <div className={`${BASE} ${surface} opacity-40`} aria-disabled="true">
        {body}
      </div>
    );
  }

  const isExternal = href.startsWith("http");

  return (
    <a
      href={href}
      {...(isExternal ? { target: "_blank", rel: "noopener noreferrer" } : {})}
      className={`${BASE} ${surface} transition-transform hover:scale-[1.02] active:scale-[0.99]`}
    >
      {body}
    </a>
  );
}
```

- [ ] **Step 4: Verify lint and build pass**

Run: `npm run lint && npm run build`
Expected: no errors. Nothing renders these yet — this only confirms they compile.

- [ ] **Step 5: Commit**

```bash
git add components/links/PlatformIcons.tsx components/links/LinkRow.tsx lib/app-links.ts
git commit -m "feat(marketing): add link row primitive and platform icons"
```

---

### Task 3: The /links page

Composes the page. After this task it is reachable at `disciplefy.in/links`; the subdomain comes in Task 4.

**Files:**
- Create: `app/links/page.tsx`

**Interfaces:**
- Consumes: `SOCIAL` from Task 1; `LinkRow`, `AndroidIcon`, `AppleIcon`, `GlobeIcon`, `MailIcon`, `APP_STORE_URL` from Task 2; `PLAY_STORE_URL` and `WEB_APP_URL` from the existing `lib/app-links.ts`
- Produces: route `/links`

- [ ] **Step 1: Create the page**

The wordmark is `public/logo-dark.png`, intrinsically 686×158. Rendered at height 36 that is width 156.

```tsx
// marketing/app/links/page.tsx
// Link-in-bio page. Served at links.disciplefy.in (see middleware.ts) and /links.
// Dark only by design: uses explicit colours, never `dark:` variants, so the
// visitor's stored theme preference cannot change it.
import type { Metadata } from "next";
import Image from "next/image";
import { LinkRow } from "@/components/links/LinkRow";
import { AndroidIcon, AppleIcon, GlobeIcon, MailIcon } from "@/components/links/PlatformIcons";
import { APP_STORE_URL, PLAY_STORE_URL, WEB_APP_URL } from "@/lib/app-links";
import { SOCIAL } from "@/lib/social-links";

export const metadata: Metadata = {
  title: "Disciplefy — All Links",
  description: "Download the Disciplefy app, follow along, or get in touch.",
  alternates: { canonical: "https://links.disciplefy.in/" },
};

const SECTION_LABEL = "mb-2.5 ml-1 mt-5 text-[10px] font-extrabold uppercase tracking-[0.11em] text-[#64748B]";

const SOCIAL_ROWS = [
  { ...SOCIAL.instagram, chipClass: "bg-gradient-to-br from-[#FEDA75] via-[#D62976] to-[#4F5BD5] text-white" },
  { ...SOCIAL.youtube, chipClass: "bg-[#FF0000] text-white" },
  { ...SOCIAL.whatsapp, chipClass: "bg-[#25D366] text-white" },
  { ...SOCIAL.facebook, chipClass: "bg-[#1877F2] text-white" },
];

const GOLD_CHIP = "bg-[#D4930A]/20 text-[#F3C766]";

export default function LinksPage() {
  return (
    <main className="min-h-screen bg-[#0F172A] px-5 py-9">
      <div className="mx-auto w-full max-w-[360px]">
        <Image
          src="/logo-dark.png"
          alt="Disciplefy"
          width={156}
          height={36}
          priority
          className="mx-auto mb-4 h-9 w-auto"
        />
        <p className="mb-6 text-center text-[13px] leading-relaxed text-[#94A3B8]">
          AI-powered Bible study guides
          <br />
          English · हिन्दी · മലയാളം
        </p>

        <p className={SECTION_LABEL}>Get the app</p>
        <div className="flex flex-col gap-2.5">
          <LinkRow
            label="Download for Android"
            href={PLAY_STORE_URL}
            variant="primary"
            chipClass="bg-white/20 text-white"
            icon={<AndroidIcon className="h-[17px] w-[17px]" />}
          />
          <LinkRow
            label="Download for iOS"
            href={APP_STORE_URL ?? undefined}
            badge={APP_STORE_URL ? undefined : "SOON"}
            chipClass="bg-white text-[#111]"
            icon={<AppleIcon className="h-[17px] w-[17px]" />}
          />
          <LinkRow
            label="Use in your browser"
            href={WEB_APP_URL}
            chipClass={GOLD_CHIP}
            icon={<GlobeIcon className="h-[17px] w-[17px]" />}
          />
        </div>

        <p className={SECTION_LABEL}>Follow along</p>
        <div className="flex flex-col gap-2.5">
          {SOCIAL_ROWS.map((s) => (
            <LinkRow
              key={s.label}
              label={s.label === "WhatsApp" ? "WhatsApp Community" : s.label}
              href={s.href}
              chipClass={s.chipClass}
              icon={<s.Icon className="h-[17px] w-[17px]" />}
            />
          ))}
        </div>

        <p className={SECTION_LABEL}>Say hello</p>
        <LinkRow
          label="hello@disciplefy.in"
          href="mailto:hello@disciplefy.in"
          chipClass={GOLD_CHIP}
          icon={<MailIcon className="h-[17px] w-[17px]" />}
        />

        <p className="mt-6 border-t border-white/10 pt-4 text-center text-[11px] text-[#64748B]">
          <a href="https://www.disciplefy.in" className="hover:text-slate-300">
            disciplefy.in
          </a>
        </p>
      </div>
    </main>
  );
}
```

- [ ] **Step 2: Verify lint and build pass**

Run: `npm run lint && npm run build`
Expected: no errors, and `/links` listed as a route in the build output.

- [ ] **Step 3: Verify the page renders correctly**

Run: `npm run dev`, open `http://localhost:10200/links`.

Confirm each of these:
- Dark background, gold wordmark visible at the top
- "Download for Android" is the gold gradient row and opens the Play Store listing
- "Download for iOS" is dimmed, shows a `SOON` pill, and is not clickable or tab-focusable
- The four social rows open the correct destinations in new tabs
- The email row opens a mail client and does **not** open a new tab
- At 320px width there is no horizontal scroll

Then set a light theme preference and confirm the page stays dark:

```
localStorage.setItem("disciplefy-theme", "light")
```

Reload. The page must be unchanged. Visit `/` afterwards to confirm the main site did go light — that proves the isolation is the page's doing, not a broken theme system.

- [ ] **Step 4: Commit**

```bash
git add app/links/page.tsx
git commit -m "feat(marketing): add link-in-bio page at /links"
```

---

### Task 4: Subdomain host rewrite

Makes `links.disciplefy.in` serve `/links`. The host check must run before the next-intl middleware so locale handling never touches the subdomain root.

**Files:**
- Modify: `middleware.ts`

**Interfaces:**
- Consumes: route `/links` from Task 3
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Rewrite the middleware**

`middleware.ts` currently default-exports `createMiddleware(...)` directly. Wrap it, keeping the existing config identical:

```ts
// marketing/middleware.ts
import createMiddleware from "next-intl/middleware";
import { NextResponse, type NextRequest } from "next/server";
import { locales, defaultLocale } from "./i18n";

const intlMiddleware = createMiddleware({
  locales,
  defaultLocale,
  localePrefix: "as-needed", // EN served at root /, HI at /hi, ML at /ml
  localeDetection: false, // Never auto-redirect based on Accept-Language; URL locale always wins
});

export default function middleware(req: NextRequest) {
  // links.disciplefy.in serves the link-in-bio page at its root. This runs
  // before the intl middleware so next-intl never applies locale handling to
  // the subdomain root. Any other path falls through and resolves normally.
  const host = req.headers.get("host") ?? "";
  if (host.startsWith("links.") && req.nextUrl.pathname === "/") {
    return NextResponse.rewrite(new URL("/links", req.url));
  }

  // /links is English-only and lives at app/links/page.tsx, NOT under
  // app/[locale]/. Without this bypass the intl middleware rewrites it to
  // /en/links, which has no route and 404s.
  if (req.nextUrl.pathname === "/links") {
    return NextResponse.next();
  }

  return intlMiddleware(req);
}

export const config = {
  matcher: ["/((?!api|og|_next|_vercel|.*\\..*).*)"],
};
```

- [ ] **Step 2: Verify lint and build pass**

Run: `npm run lint && npm run build`
Expected: no errors.

- [ ] **Step 3: Verify the rewrite locally**

Run `npm run dev`, then in another terminal.

First, the direct path — this is what the locale bypass fixes, and it 404s without it:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:10200/links
```

Expected: `200`. If this returns `404`, check the response for an `x-middleware-rewrite: /en/links` header — that means the bypass is not taking effect.

Then the subdomain root:

```bash
curl -s -H "Host: links.disciplefy.in" http://localhost:10200/ | grep -c "Download for Android"
```

Expected: `1` or greater.

Confirm the normal host is unaffected:

```bash
curl -s http://localhost:10200/ | grep -c "Download for Android"
```

Expected: `0` — the marketing homepage, not the links page.

And that other paths still work on the subdomain:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "Host: links.disciplefy.in" http://localhost:10200/privacy
```

Expected: `200`.

- [ ] **Step 4: Commit**

```bash
git add middleware.ts
git commit -m "feat(marketing): serve links page on links subdomain"
```

---

### Task 5: Domain configuration and production verification

No code. These steps are performed in the Vercel and DNS dashboards by a human, then verified.

**Files:** none

**Interfaces:**
- Consumes: the deployed rewrite from Task 4

- [ ] **Step 1: Merge and deploy**

The marketing deploy workflow triggers on pushes to `main` touching `marketing/**` (`.github/workflows/marketing-deploy.yml:5-8`). Open a PR from the working branch to `main` and merge it, or push directly if that is the established practice for this repo.

- [ ] **Step 2: Add the domain in Vercel**

Vercel → the marketing project → Settings → Domains → Add → `links.disciplefy.in`.

- [ ] **Step 3: Add the DNS record**

At the DNS provider for `disciplefy.in`:

```
Type: CNAME    Name: links    Value: cname.vercel-dns.com
```

Wait for Vercel to report the domain as Valid and the certificate as issued. `vercel.json:12` already sets HSTS with `includeSubDomains; preload`, so the subdomain must serve HTTPS from its first request — Vercel handles this once the certificate issues, but the domain will appear broken until then.

- [ ] **Step 4: Verify in production**

```bash
curl -sI https://links.disciplefy.in/ | head -1
```
Expected: `HTTP/2 200`

```bash
curl -s https://links.disciplefy.in/ | grep -c "Download for Android"
```
Expected: `1` or greater

Open `https://links.disciplefy.in` on a real phone. Confirm the layout matches the approved design and every link resolves.

- [ ] **Step 5: Update the social bios**

Replace the link in the Instagram, YouTube, and Facebook bios with `https://links.disciplefy.in`.

---

## Follow-up (not part of this plan)

When the iOS app clears App Review, set `APP_STORE_URL` in `lib/app-links.ts` to the real listing URL. The disabled row activates automatically — no other file changes. At that point decide whether Android should remain the sole gold CTA or whether the treatment should switch based on the visitor's platform; the spec leaves this open deliberately.
