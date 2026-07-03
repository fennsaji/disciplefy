"use client";
// marketing/components/sections/MissionValues.tsx
import { useTranslations } from "next-intl";
import { motion } from "framer-motion";
import { BookMarked, HeartHandshake, Sprout } from "lucide-react";

const cards = [
  { key: "biblical", Icon: BookMarked },
  { key: "practical", Icon: HeartHandshake },
  { key: "growth", Icon: Sprout },
] as const;

export function MissionValues() {
  const t = useTranslations("values");

  return (
    <section id="values" className="py-24">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-2xl mx-auto mb-14">
          <motion.h2
            className="font-display font-bold text-3xl sm:text-4xl mb-4"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            {t("heading")}
          </motion.h2>
          <motion.p
            className="text-lg text-[var(--muted)]"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.1 }}
          >
            {t("mission")}
          </motion.p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {cards.map(({ key, Icon }, i) => (
            <motion.div
              key={key}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ duration: 0.5, delay: i * 0.1 }}
              className="p-6 rounded-2xl bg-[var(--surface)] border border-[var(--border)] h-full"
            >
              <div className="mb-4 w-10 h-10 rounded-xl bg-gold-light/60 dark:bg-gold/10 flex items-center justify-center" aria-hidden="true">
                <Icon className="w-5 h-5 text-gold" strokeWidth={1.75} />
              </div>
              <h3 className="font-display font-semibold text-lg mb-2">{t(`${key}.title`)}</h3>
              <p className="text-sm text-[var(--muted)] leading-relaxed">{t(`${key}.desc`)}</p>
            </motion.div>
          ))}
        </div>

        <motion.p
          className="text-center text-base text-[var(--muted)] max-w-3xl mx-auto mt-12"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          {t("promise")}
        </motion.p>
      </div>
    </section>
  );
}
