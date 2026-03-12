"use client";
// marketing/components/sections/Testimonials.tsx
import { useTranslations } from "next-intl";
import { motion } from "framer-motion";

const testimonials = [
  {
    quote: "Disciplefy has transformed my sermon preparation. I get deep insights in minutes.",
    name: "Rev. Thomas M.",
    location: "Ernakulam, Kerala",
    role: "Pastor",
  },
  {
    quote: "मैं हिंदी में बाइबल पढ़ और समझ सकती हूँ। यह बहुत आशीषमय है।",
    name: "Sunita P.",
    location: "Lucknow, UP",
    role: "Homemaker",
    font: "devanagari",
  },
  {
    quote: "Finally a Bible app that feels modern and actually explains the context.",
    name: "Akhil R.",
    location: "Bangalore",
    role: "Software Engineer",
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
            <motion.div
              key={item.name}
              className="p-6 rounded-2xl bg-[var(--bg)] border border-[var(--border)] snap-start shrink-0 min-w-[280px] md:min-w-0"
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ duration: 0.5, delay: index * 0.1 }}
              whileHover={{ y: -3 }}
            >
              <div className="text-yellow-400 text-sm mb-4">★★★★★</div>
              <p className={`text-[var(--text)] leading-relaxed mb-6 ${item.font === "devanagari" ? "font-devanagari" : ""}`}>
                &ldquo;{item.quote}&rdquo;
              </p>
              <div>
                <p className="font-semibold text-sm">{item.name}</p>
                <p className="text-xs text-[var(--muted)]">{item.role} · {item.location}</p>
              </div>
            </motion.div>
          ))}
        </div>
        <p className="text-center text-xs text-[var(--muted)] mt-6 italic">
          * Testimonials are representative placeholders. Replace with real user quotes before launch.
        </p>
      </div>
    </section>
  );
}
