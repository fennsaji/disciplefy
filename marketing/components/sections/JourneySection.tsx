"use client";
// marketing/components/sections/JourneySection.tsx
import { useTranslations } from "next-intl";
import { motion } from "framer-motion";
import { BookOpen, Sprout, Footprints } from "lucide-react";

const beats = [
  { key: "know", Icon: BookOpen },
  { key: "grow", Icon: Sprout },
  { key: "follow", Icon: Footprints },
] as const;

export function JourneySection() {
  const t = useTranslations("journey");

  return (
    <section id="journey" className="py-24 bg-[var(--surface)]">
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <motion.p
          className="text-gold font-semibold uppercase tracking-wide text-sm mb-4"
          initial={{ opacity: 0, y: 12 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.4 }}
        >
          {t("eyebrow")}
        </motion.p>
        <motion.h2
          className="font-display font-bold text-3xl sm:text-4xl leading-snug mb-6"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          {t("heading")}
        </motion.h2>
        <motion.p
          className="text-lg text-[var(--muted)] max-w-2xl mx-auto mb-14"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: 0.1 }}
        >
          {t("body")}
        </motion.p>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-8">
          {beats.map(({ key, Icon }, i) => (
            <motion.div
              key={key}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ duration: 0.5, delay: i * 0.1 }}
              className="flex flex-col items-center"
            >
              <div className="mb-4 w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center" aria-hidden="true">
                <Icon className="w-6 h-6 text-primary" strokeWidth={1.75} />
              </div>
              <h3 className="font-display font-semibold text-lg mb-1">{t(`${key}.title`)}</h3>
              <p className="text-sm text-[var(--muted)] leading-relaxed max-w-[16rem]">{t(`${key}.desc`)}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
