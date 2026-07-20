"use client";
// marketing/components/layout/Footer.tsx
import { useTranslations } from "next-intl";
import { motion } from "framer-motion";
import { Link } from "@/lib/navigation"; // locale-aware — preserves /hi/ /ml/ prefix
import { LocaleSwitcher } from "@/components/ui/LocaleSwitcher";
import { SOCIAL_LINKS } from "@/lib/social-links";

export function Footer() {
  const t = useTranslations("footer");

  return (
    <footer className="border-t border-[var(--border)] bg-[var(--surface)] mt-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
          {/* Brand */}
          <motion.div
            className="col-span-2 md:col-span-1"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-50px" }}
            transition={{ duration: 0.5, delay: 0 }}
          >
            <p className="font-display font-bold text-xl text-primary mb-2">Disciplefy</p>
            <p className="text-sm text-[var(--muted)] mb-4">{t("tagline")}</p>
            <div className="flex gap-3">
              {SOCIAL_LINKS.map((s) => (
                <a key={s.label} href={s.href} target="_blank" rel="noopener noreferrer" aria-label={s.label}
                   className="text-[var(--muted)] hover:text-[var(--text)] hover:scale-110 transition-all"><s.Icon /></a>
              ))}
            </div>
          </motion.div>
          {/* Product */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-50px" }}
            transition={{ duration: 0.5, delay: 0.1 }}
          >
            <p className="font-semibold text-sm mb-3">{t("product")}</p>
            <div className="flex flex-col gap-2">
              <Link href="/features/ai-bible-study" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("aiStudy")}</Link>
              <Link href="/features/daily-verse" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("dailyVerse")}</Link>
              <Link href="/features/study-guides" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("studyGuides")}</Link>
              <Link href="/features/fellowship" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("fellowship")}</Link>
              <Link href="/features/voice-buddy" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("voiceBuddy")}</Link>
              <Link href="/features/memory-verses" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("memoryVerses")}</Link>
              <Link href="/features/learning-paths" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("learningPaths")}</Link>
              <Link href="/features/follow-up-chat" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("followUpChat")}</Link>
              <Link href="/pricing" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("pricing")}</Link>
              <Link href="/download" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("download")}</Link>
            </div>
          </motion.div>
          {/* Company */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-50px" }}
            transition={{ duration: 0.5, delay: 0.2 }}
          >
            <p className="font-semibold text-sm mb-3">{t("company")}</p>
            <div className="flex flex-col gap-2">
              <Link href="/about" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("about")}</Link>
              <Link href="/blog" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("blog")}</Link>
              <Link href="/contact" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("contact")}</Link>
            </div>
          </motion.div>
          {/* Legal */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-50px" }}
            transition={{ duration: 0.5, delay: 0.3 }}
          >
            <p className="font-semibold text-sm mb-3">{t("legal")}</p>
            <div className="flex flex-col gap-2">
              <Link href="/privacy" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("privacy")}</Link>
              <Link href="/terms" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("terms")}</Link>
              <Link href="/refund" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("refund")}</Link>
            </div>
          </motion.div>
        </div>

        <div className="mt-12 pt-8 border-t border-[var(--border)] flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-xs text-[var(--muted)]">© 2026 Disciplefy. {t("copyright")}</p>
          <LocaleSwitcher />
        </div>
      </div>
    </footer>
  );
}
