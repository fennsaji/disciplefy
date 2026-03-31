"use client";
// marketing/components/sections/Features.tsx
import { useTranslations } from "next-intl";
import { motion } from "framer-motion";
import { Link } from "@/lib/navigation";
import { BookOpen, Brain, Sparkles, Sun, Mic, Users } from "lucide-react";

const featureIcons = [BookOpen, Brain, Sparkles, Sun, Mic, Users];
const featureKeys = ["paths", "memory", "aiGuides", "dailyVerse", "voiceBuddy", "fellowship"] as const;
const featureHrefs: Record<typeof featureKeys[number], string> = {
  paths: "/features/learning-paths",
  memory: "/features/memory-verses",
  aiGuides: "/features/ai-bible-study",
  dailyVerse: "/features/daily-verse",
  voiceBuddy: "/features/voice-buddy",
  fellowship: "/features/fellowship",
};

export function Features() {
  const t = useTranslations("features");

  return (
    <section id="features" className="py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.h2
          className="font-display font-bold text-3xl sm:text-4xl text-center mb-16"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          {t("title")}
        </motion.h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {featureKeys.map((key, i) => {
            const Icon = featureIcons[i];
            return (
              <motion.div
                key={key}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ duration: 0.5, delay: i * 0.1 }}
                whileHover={{ y: -4, transition: { duration: 0.2 } }}
              >
                <Link
                  href={featureHrefs[key]}
                  className="block p-6 rounded-2xl bg-[var(--surface)] border border-[var(--border)] hover:border-primary/30 transition-colors h-full cursor-pointer"
                >
                  <div className="mb-4 w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center" aria-hidden="true">
                    <Icon className="w-5 h-5 text-primary" strokeWidth={1.75} />
                  </div>
                  <h3 className="font-display font-semibold text-lg mb-2">{t(`${key}.title`)}</h3>
                  <p className="text-sm text-[var(--muted)] leading-relaxed">{t(`${key}.desc`)}</p>
                </Link>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
