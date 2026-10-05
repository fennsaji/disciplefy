// marketing/components/links/LinksPage.tsx
// Link-in-bio page, served at links.disciplefy.in and /links.
//
// One warm light source above the logo, a single glowing gold button for the
// visitor's own store, and the social channels as a quiet row of round
// icons. Dark mode feels like a lamp at night, light mode like dawn.
import Image from "next/image";
import { PlatformDetector } from "@/components/links/DeviceSlots";
import { DownloadButtons } from "@/components/links/DownloadButtons";
import { SocialIcons } from "@/components/links/SocialIcons";
import { CONTACT_LINKS, FOCUS_RING, linkProps } from "@/components/links/link-data";

const THEME =
  "[--bg:#FFF9EC] [--glow:rgba(212,147,10,0.30)] [--ink:#241A05] [--muted:#5F5338] [--line:rgba(36,26,5,0.14)] [--glass:rgba(255,255,255,0.7)] [--gold-ink:#8A6408] " +
  "dark:[--bg:#0D0C14] dark:[--glow:rgba(212,147,10,0.34)] dark:[--ink:#EDE7DA] dark:[--muted:#A9A296] dark:[--line:rgba(243,199,102,0.2)] dark:[--glass:rgba(255,255,255,0.05)] dark:[--gold-ink:#F3C766]";

// Fine film grain so the dark field is never flat.
const GRAIN =
  "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.05'/%3E%3C/svg%3E\")";

export function LinksPage() {
  return (
    <main
      className={`${THEME} relative min-h-screen overflow-hidden bg-[color:var(--bg)] px-5 pb-14 pt-12 text-[color:var(--ink)]`}
    >
      <PlatformDetector />
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-0 top-0 h-[520px]"
        style={{ background: "radial-gradient(60% 75% at 50% 0%, var(--glow), transparent 70%)" }}
      />
      <div aria-hidden="true" className="pointer-events-none absolute inset-0" style={{ backgroundImage: GRAIN }} />

      <div className="relative mx-auto flex w-full max-w-[400px] flex-col items-center text-center">
        <Image src="/logo-light.png" alt="Disciplefy" width={527} height={160} priority className="h-12 w-auto dark:hidden" />
        <Image src="/logo-dark.png" alt="Disciplefy" width={527} height={160} priority className="hidden h-12 w-auto dark:block" />

        <h1 className="mt-8 font-display text-[28px] font-semibold leading-[1.2] tracking-[-0.01em] [text-wrap:balance]">
          Sit with the Word.
          <br />
          Go deeper every day.
        </h1>
        <p className="mt-4 text-[15px] leading-relaxed text-[color:var(--muted)]">
          Guided Bible study in English, <span className="font-devanagari">हिन्दी</span> and{" "}
          <span className="font-malayalam">മലയാളം</span>.
        </p>

        <div className="mt-9 w-full">
          <DownloadButtons />
        </div>

        <div className="mt-12 flex w-full items-center gap-4" aria-hidden="true">
          <span className="h-px flex-1 bg-[color:var(--line)]" />
          <span className="h-1.5 w-1.5 rounded-full bg-[#D4930A]" />
          <span className="h-px flex-1 bg-[color:var(--line)]" />
        </div>

        <h2 className="mt-8 font-display text-[17px] font-semibold">Follow along</h2>
        <div className="mt-5 w-full">
          <SocialIcons />
        </div>

        <ul className="mt-10 flex w-full flex-col gap-2.5">
          {CONTACT_LINKS.map((l) => (
            <li key={l.label}>
              <a
                {...linkProps(l.href)}
                className={`flex min-h-[56px] items-center gap-3 rounded-2xl border border-[color:var(--line)] bg-[color:var(--glass)] px-4 text-left transition-colors hover:border-[#D4930A] ${FOCUS_RING}`}
              >
                <l.Icon className="h-5 w-5 shrink-0 text-[color:var(--gold-ink)]" />
                <span className="flex flex-col leading-tight">
                  <span className="text-[15px] font-semibold">{l.label}</span>
                  <span className="text-[12.5px] text-[color:var(--muted)]">{l.detail}</span>
                </span>
              </a>
            </li>
          ))}
        </ul>
      </div>
    </main>
  );
}
