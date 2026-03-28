// marketing/components/sections/DownloadPageContent.tsx
"use client";
import { useTranslations } from "next-intl";
import { motion } from "framer-motion";
import { track } from "@vercel/analytics";
import { PLAY_STORE_URL } from "@/lib/app-links";

const FEATURES = [
  { icon: "✝", key: "feature1" },
  { icon: "🎤", key: "feature2" },
  { icon: "📖", key: "feature3" },
  { icon: "🌐", key: "feature4" },
] as const;

export function DownloadPageContent({ jsonLd }: { jsonLd: string }) {
  const t = useTranslations("downloadPage");

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: jsonLd }}
      />
      <main className="min-h-screen">
        {/* Hero */}
        <section className="py-24 px-4 sm:px-6 lg:px-8 text-center max-w-3xl mx-auto">
          <motion.div
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
          >
            <div className="inline-flex items-center gap-2 bg-gold-light/60 dark:bg-gold/10 border border-gold/30 text-gold px-3.5 py-1.5 rounded-full text-sm font-semibold mb-6">
              <span>Free · Android</span>
            </div>
            <h1 className="font-display font-extrabold text-4xl sm:text-5xl mb-4 leading-snug">
              {t("title")}
            </h1>
            <p className="text-[var(--muted)] text-lg mb-10 max-w-xl mx-auto">
              {t("subtitle")}
            </p>

            {/* CTAs — Play Store + Web App as equal choices */}
            <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
              <a
                href={PLAY_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={t("cta")}
                className="inline-flex items-center gap-2.5 bg-primary text-white px-6 py-3.5 rounded-xl text-base font-semibold hover:bg-primary/90 transition-colors shadow-lg shadow-primary/30 w-full sm:w-auto justify-center"
                onClick={() => track("play_store_click", { source: "download_page_hero" })}
              >
                <svg viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 shrink-0" aria-hidden="true">
                  <path d="M3.18 23.76c.37.2.8.19 1.17-.03L16.83 12 12.5 7.67 3.18 23.76zm-1.62-2.1c-.12-.22-.18-.47-.18-.73V3.07c0-.26.06-.51.18-.73l9.5 9.66-9.5 9.66zm20.28-9.19c.41.22.66.61.66 1.02 0 .41-.25.8-.66 1.02l-2.7 1.54-3.45-3.51 3.45-3.51 2.7 1.44zM4.35.27l11.48 6.57L12.5 10.17 3.35.24c.37-.17.79-.16 1-.03z" />
                </svg>
                {t("cta")}
              </a>
              <a
                href="https://app.disciplefy.in"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2.5 border-2 border-primary text-primary px-6 py-3.5 rounded-xl text-base font-semibold hover:bg-primary/5 transition-colors w-full sm:w-auto justify-center"
                onClick={() => track("web_app_click", { source: "download_page_hero" })}
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-5 h-5 shrink-0" aria-hidden="true">
                  <circle cx="12" cy="12" r="10" /><path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
                </svg>
                {t("webAppCta")}
              </a>
            </div>
          </motion.div>
        </section>

        {/* Feature bullets */}
        <section className="py-12 bg-[var(--surface)] border-t border-[var(--border)]">
          <div className="max-w-2xl mx-auto px-4 sm:px-6 grid sm:grid-cols-2 gap-6">
            {FEATURES.map(({ icon, key }, i) => (
              <motion.div
                key={key}
                className="flex items-start gap-4 p-5 rounded-2xl bg-[var(--bg)] border border-[var(--border)]"
                initial={{ opacity: 0, y: 16 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.4, delay: i * 0.08 }}
              >
                <span className="text-2xl mt-0.5" aria-hidden="true">{icon}</span>
                <div>
                  <h3 className="font-semibold mb-1">{t(`${key}.title`)}</h3>
                  <p className="text-sm text-[var(--muted)]">{t(`${key}.desc`)}</p>
                </div>
              </motion.div>
            ))}
          </div>
        </section>

        {/* FAQ */}
        <section className="py-16 px-4 sm:px-6 max-w-2xl mx-auto">
          <h2 className="font-display font-bold text-2xl mb-8 text-center">{t("faqTitle")}</h2>
          <div className="space-y-6">
            {(["q1", "q2", "q3", "q4"] as const).map((key) => (
              <div key={key} className="border-b border-[var(--border)] pb-6">
                <h3 className="font-semibold mb-2">{t(`${key}.q`)}</h3>
                <p className="text-[var(--muted)] text-sm">{t(`${key}.a`)}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Sticky bottom CTA */}
        <div className="sticky bottom-0 bg-[var(--bg)]/90 backdrop-blur border-t border-[var(--border)] py-3 px-4 flex items-center justify-center gap-2">
          <a
            href={PLAY_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 bg-primary text-white px-4 py-2.5 rounded-xl text-sm font-semibold hover:bg-primary/90 transition-colors"
            onClick={() => track("play_store_click", { source: "download_page_sticky" })}
          >
            <svg viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4 shrink-0" aria-hidden="true">
              <path d="M3.18 23.76c.37.2.8.19 1.17-.03L16.83 12 12.5 7.67 3.18 23.76zm-1.62-2.1c-.12-.22-.18-.47-.18-.73V3.07c0-.26.06-.51.18-.73l9.5 9.66-9.5 9.66zm20.28-9.19c.41.22.66.61.66 1.02 0 .41-.25.8-.66 1.02l-2.7 1.54-3.45-3.51 3.45-3.51 2.7 1.44zM4.35.27l11.48 6.57L12.5 10.17 3.35.24c.37-.17.79-.16 1-.03z" />
            </svg>
            {t("cta")}
          </a>
          <a
            href="https://app.disciplefy.in"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 border border-primary text-primary px-4 py-2.5 rounded-xl text-sm font-semibold hover:bg-primary/5 transition-colors"
            onClick={() => track("web_app_click", { source: "download_page_sticky" })}
          >
            {t("webAppCta")}
          </a>
        </div>
      </main>
    </>
  );
}
