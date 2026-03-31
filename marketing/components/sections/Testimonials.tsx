"use client";
// marketing/components/sections/Testimonials.tsx
import { useTranslations } from "next-intl";
import { motion } from "framer-motion";

const testimonials = [
  {
    quote: "My quiet time has completely changed. I feel like I actually know God more deeply now — His character, His promises. Scripture feels alive to me in a way it never did before.",
    name: "Anju S.",
    location: "Kottayam, Kerala",
    role: "College Student",
  },
  {
    quote: "Disciplefy ने मुझे परमेश्वर के वचन को गहराई से समझने में मदद की। अब मेरी प्रार्थना और विश्वास दोनों मज़बूत हो रहे हैं।",
    name: "Rahul K.",
    location: "Varanasi, UP",
    role: "Youth Leader",
    font: "devanagari",
  },
  {
    quote: "I've memorised more verses in the last few months than in years. The daily verse and study guides keep me rooted in God's Word consistently.",
    name: "David J.",
    location: "Chennai",
    role: "IT Professional",
  },
];

export function Testimonials() {
  const t = useTranslations("testimonials");

  return (
    <section className="py-24 bg-[var(--surface)]">
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
        {/* Mobile: horizontal scroll carousel. Tablet+: 3-column grid */}
        <div className="flex gap-6 overflow-x-auto snap-x snap-mandatory pb-4 md:grid md:grid-cols-3 md:overflow-visible md:snap-none">
          {testimonials.map((item, index) => (
            <motion.article
              key={item.name}
              className="p-6 rounded-2xl bg-[var(--bg)] border border-[var(--border)] snap-start shrink-0 min-w-[280px] md:min-w-0"
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ duration: 0.5, delay: index * 0.1 }}
              whileHover={{ y: -3 }}
              whileTap={{ y: -3 }}
            >
              <div className="text-[#D4930A] text-sm mb-4">★★★★★</div>
              <p className={`text-[var(--text)] leading-relaxed mb-6 ${item.font === "devanagari" ? "font-devanagari" : ""}`}>
                &ldquo;{item.quote}&rdquo;
              </p>
              <div>
                <p className="font-semibold text-sm flex items-center gap-1.5">
                  {item.name}
                  <span className="inline-flex items-center gap-0.5 bg-emerald-50 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400 text-[10px] font-medium px-1.5 py-0.5 rounded-full border border-emerald-200 dark:border-emerald-700">
                    <svg viewBox="0 0 12 12" fill="currentColor" className="w-2.5 h-2.5" aria-hidden="true"><path d="M10.28 1.28L4 7.56 1.72 5.28a1 1 0 00-1.44 1.44l3 3a1 1 0 001.44 0l7-7a1 1 0 00-1.44-1.44z"/></svg>
                    Verified
                  </span>
                </p>
                <p className="text-xs text-[var(--muted)]">{item.role} · {item.location}</p>
              </div>
            </motion.article>
          ))}
        </div>
      </div>
    </section>
  );
}
