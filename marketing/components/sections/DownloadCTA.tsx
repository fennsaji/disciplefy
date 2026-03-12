"use client";
// marketing/components/sections/DownloadCTA.tsx
import { useTranslations } from "next-intl";
import { motion } from "framer-motion";
import { AppStoreBadges } from "@/components/ui/AppStoreBadges";

export function DownloadCTA() {
  const t = useTranslations("downloadCTA");

  return (
    <section className="py-24 relative overflow-hidden">
      {/* Scripture texture background — slow eternal spin */}
      <motion.div
        className="absolute inset-0 flex items-center justify-center opacity-[0.03] select-none pointer-events-none"
        animate={{ rotate: 360 }}
        transition={{ duration: 60, repeat: Infinity, ease: "linear" }}
      >
        <p className="font-display text-[15vw] font-extrabold text-center leading-none">
          ✝
        </p>
      </motion.div>
      <div className="relative max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <motion.h2
          className="font-display font-extrabold text-4xl sm:text-5xl mb-4"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          {t("title")}
        </motion.h2>
        <motion.p
          className="text-[var(--muted)] text-lg mb-10"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: 0.1 }}
        >
          {t("subtitle")}
        </motion.p>
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: 0.2 }}
        >
          <AppStoreBadges className="justify-center" />
        </motion.div>
      </div>
    </section>
  );
}
