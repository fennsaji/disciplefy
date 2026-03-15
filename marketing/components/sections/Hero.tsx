// marketing/components/sections/Hero.tsx
"use client";
import { useTranslations, useLocale } from "next-intl";
import { motion } from "framer-motion";
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
      onError={() => setFailed(true)}
    />
  );
}

export function Hero() {
  const t = useTranslations("hero");
  const locale = useLocale();

  return (
    <section className="relative min-h-[90vh] flex items-center overflow-hidden">
      {/* Subtle gold radial glow — top-left behind headline */}
      <div
        className="pointer-events-none absolute -top-32 -left-32 w-[600px] h-[600px] rounded-full opacity-[0.12] dark:opacity-[0.07]"
        style={{ background: "radial-gradient(circle, #FFEEC0 0%, transparent 70%)" }}
      />

      <div className="relative max-w-7xl mx-auto px-6 sm:px-8 lg:px-12 py-24 w-full">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Text */}
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
          >
            {/* Gold eyebrow chip */}
            <motion.div
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: 0.1 }}
              className="inline-flex items-center gap-2 bg-gold-light/60 dark:bg-gold/10 border border-gold/30 text-gold px-3.5 py-1.5 rounded-full text-sm font-semibold mb-6"
            >
              <span className="text-base">✝</span>
              <span>Free · English, हिन्दी &amp; മലയാളം</span>
            </motion.div>

            {/* Headline — accent in gold */}
            <div className="mb-8">
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
            <p className="text-lg text-[var(--muted)] mb-10 max-w-lg">
              {t("subheadline")}
            </p>
            <AppStoreBadges />
          </motion.div>

          {/* S26 Ultra phone mockup */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="flex justify-center"
          >
            <div className="relative w-[300px] h-[640px] rounded-[12px] border-2 border-[var(--border)] bg-neutral-900 shadow-2xl overflow-hidden">
              {/* Thin bezel frame */}
              <div className="absolute inset-0 rounded-[12px] border border-neutral-700/40" />
              {/* Punch-hole camera */}
              <div className="absolute top-3 left-1/2 -translate-x-1/2 w-2.5 h-2.5 rounded-full bg-neutral-800 ring-1 ring-neutral-600/50 z-20" />
              {/* Screen */}
              <div className="absolute inset-[6px] rounded-[8px] overflow-hidden bg-[var(--surface)]">
                <HeroScreenshot locale={locale} />
              </div>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
