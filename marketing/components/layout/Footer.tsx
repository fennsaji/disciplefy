"use client";
// marketing/components/layout/Footer.tsx
import { useTranslations } from "next-intl";
import { motion } from "framer-motion";
import { Link } from "@/lib/navigation"; // locale-aware — preserves /hi/ /ml/ prefix
import { LocaleSwitcher } from "@/components/ui/LocaleSwitcher";

export function Footer() {
  const t = useTranslations("footer");

  const socials = [
    { label: "Instagram", href: "https://instagram.com/disciplefy.app", icon: "📸" },
    { label: "YouTube", href: "https://youtube.com/@disciplefy", icon: "▶️" },
    { label: "Facebook", href: "https://facebook.com/disciplefy", icon: "👥" },
    { label: "WhatsApp", href: "https://whatsapp.com/channel/disciplefy", icon: "💬" },
  ];

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
              {socials.map((s) => (
                <a key={s.label} href={s.href} target="_blank" rel="noopener noreferrer" aria-label={s.label}
                   className="text-lg hover:scale-110 transition-transform">{s.icon}</a>
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
              <Link href="/#features" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("features")}</Link>
              <Link href="/pricing" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("pricing")}</Link>
              <Link href="https://app.disciplefy.in" className="text-sm text-[var(--muted)] hover:text-[var(--text)]">{t("download")}</Link>
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
