// marketing/components/sections/Hero.tsx
// PERFORMANCE NOTES:
// 1. No framer-motion — removed to eliminate 57KB JS from critical path.
// 2. The H1 (LCP element) has NO opacity animation on any ancestor div.
//    Lighthouse won't count opacity:0 elements as "painted" — this was causing
//    5s+ LCP. H1 renders immediately; only secondary elements animate.
// 3. CSS animations (animate-hero-*) start when CSS parses — no JS needed.
"use client";
import { useTranslations, useLocale } from "next-intl";
import Image from "next/image";
import { useState } from "react";
import { AppStoreBadges } from "@/components/ui/AppStoreBadges";

function HeroScreenshot({ locale }: { locale: string }) {
  const [failed, setFailed] = useState(false);

  if (failed) {
    return (
      <div className="w-full h-full flex items-center justify-center">
        <p className="text-[var(--muted)] text-sm text-center px-6">
          App mockup image<br />(replace with real screenshot)
        </p>
      </div>
    );
  }

  return (
    <Image
      src={`/screenshots/hero-${locale}.jpg`}
      alt="Disciplefy Bible study app home screen showing daily verse and AI study guide features"
      fill
      className="object-cover object-top"
      sizes="300px"
      priority
      fetchPriority="high"
      onError={() => setFailed(true)}
    />
  );
}

export function Hero() {
  const t = useTranslations("hero");
  const locale = useLocale();

  return (
    <section className="relative min-h-[90vh] flex items-center overflow-hidden">
      {/* Subtle gold radial glow */}
      <div
        className="pointer-events-none absolute -top-32 -left-32 w-[600px] h-[600px] rounded-full opacity-[0.12] dark:opacity-[0.07]"
        style={{ background: "radial-gradient(circle, #FFEEC0 0%, transparent 70%)" }}
      />

      <div className="relative max-w-7xl mx-auto px-6 sm:px-8 lg:px-12 py-24 w-full">
        <div className="grid lg:grid-cols-2 gap-12 items-center">

          {/* ── Text column ────────────────────────────────────────────────────
              NO opacity-0 wrapper around this column.
              The H1 is the LCP element — it must paint immediately.
              Each non-LCP child element has its own entrance animation.        */}
          <div>
            {/* Eyebrow chip — animates in from above (not LCP) */}
            <div className="animate-hero-eyebrow inline-flex items-center gap-2 bg-gold-light/60 dark:bg-gold/10 border border-gold/30 text-amber-900 dark:text-amber-300 px-3.5 py-1.5 rounded-full text-sm font-semibold mb-6">
              <span className="text-base">✝</span>
              <span>Free · English, हिन्दी &amp; മലയാളം</span>
            </div>

            {/* ── Headline (LCP element) — transform-only slide-up, opacity stays 1 so LCP is not delayed ── */}
            <div className="animate-hero-headline mb-8">
              <h1
                className={`font-extrabold text-4xl sm:text-5xl lg:text-6xl leading-snug mb-4 ${
                  locale === "en" ? "font-display" : locale === "hi" ? "font-devanagari" : "font-malayalam"
                }`}
              >
                {t("headline").split("\n").map((line, i, arr) => (
                  <span key={i}>{line}{i < arr.length - 1 && <br />}</span>
                ))}
                <br />
                <span className="text-gold">{t("headlineAccent")}</span>
              </h1>
              {locale === "en" && (
                <div className="space-y-1 mt-3">
                  <p className="font-devanagari text-xl text-[var(--muted)] font-semibold">
                    बाइबल। समझी गई। <span className="text-gold">आपकी भाषा में।</span>
                  </p>
                  <p className="font-malayalam text-xl text-[var(--muted)] font-semibold">
                    ബൈബിൾ. മനസ്സിലായി. <span className="text-gold">നിങ്ങളുടെ ഭാഷയിൽ.</span>
                  </p>
                </div>
              )}
            </div>

            {/* Subtitle & CTA — animate in after H1 is visible */}
            <div className="animate-hero-sub">
              <p className="text-lg text-[var(--muted)] mb-6 max-w-lg">
                {t("subheadline")}
              </p>
              {/* In-fold trust signal */}
              <div className="flex items-center gap-2 mb-6">
                <span className="text-[#D4930A]" aria-hidden="true">★★★★★</span>
                <span className="text-sm text-[var(--muted)]">4.9 · 1,200+ ratings</span>
              </div>
              <AppStoreBadges />
            </div>
          </div>

          {/* Phone mockup — scale-fade in, no delay */}
          <div className="animate-hero-phone flex justify-center">
            <div className="relative w-full max-w-[300px] h-[640px] rounded-[12px] border-2 border-[var(--border)] bg-neutral-900 shadow-2xl overflow-hidden">
              <div className="absolute inset-0 rounded-[12px] border border-neutral-700/40" />
              <div className="absolute top-3 left-1/2 -translate-x-1/2 w-2.5 h-2.5 rounded-full bg-neutral-800 ring-1 ring-neutral-600/50 z-20" />
              <div className="absolute inset-[6px] rounded-[8px] overflow-hidden bg-[var(--surface)]">
                <HeroScreenshot locale={locale} />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
