// marketing/components/sections/DownloadSection.tsx
"use client";
import { useTranslations, useLocale } from "next-intl";
import { motion } from "framer-motion";
import Link from "next/link";

export function DownloadSection() {
  const t = useTranslations("downloadSection");
  const locale = useLocale();
  const downloadHref = locale === "en" ? "/download" : `/${locale}/download`;

  return (
    <section className="py-16 bg-primary/5 border-y border-primary/10">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <motion.h2
          className="font-display font-bold text-2xl sm:text-3xl mb-2"
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.4 }}
        >
          {t("title")}
        </motion.h2>
        <motion.p
          className="text-[var(--muted)] mb-7"
          initial={{ opacity: 0, y: 12 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.4, delay: 0.08 }}
        >
          {t("subtitle")}
        </motion.p>
        <motion.div
          className="flex flex-wrap items-center justify-center gap-3"
          initial={{ opacity: 0, y: 12 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.4, delay: 0.16 }}
        >
          <Link
            href={downloadHref}
            aria-label={t("cta")}
            className="inline-flex items-center gap-2 bg-primary text-white px-5 py-3 rounded-xl text-sm font-semibold hover:bg-primary/90 transition-colors shadow-md shadow-primary/25"
          >
            <svg viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5" aria-hidden="true">
              <path d="M3.18 23.76c.37.2.8.19 1.17-.03L16.83 12 12.5 7.67 3.18 23.76zm-1.62-2.1c-.12-.22-.18-.47-.18-.73V3.07c0-.26.06-.51.18-.73l9.5 9.66-9.5 9.66zm20.28-9.19c.41.22.66.61.66 1.02 0 .41-.25.8-.66 1.02l-2.7 1.54-3.45-3.51 3.45-3.51 2.7 1.44zM4.35.27l11.48 6.57L12.5 10.17 3.35.24c.37-.17.79-.16 1-.03z" />
            </svg>
            {t("cta")}
          </Link>
          <a
            href="https://app.disciplefy.in"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm font-medium text-[var(--muted)] hover:text-[var(--fg)] transition-colors underline underline-offset-4"
          >
            {t("openWebApp")}
          </a>
        </motion.div>
      </div>
    </section>
  );
}
