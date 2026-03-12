// marketing/components/sections/SocialProof.tsx
"use client";
import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

const verses = [
  '"I can do all things through Christ who strengthens me." — Phil 4:13',
  '"Your word is a lamp to my feet and a light to my path." — Ps 119:105',
  '"For God so loved the world..." — John 3:16',
];

export function SocialProof() {
  const [idx, setIdx] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setIdx((i) => (i + 1) % verses.length), 4000);
    return () => clearInterval(id);
  }, []);

  return (
    <motion.div
      className="border-y border-[var(--border)] bg-[var(--surface)] py-6"
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5 }}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <span className="text-yellow-400 text-lg">★★★★★</span>
          <span className="text-sm text-[var(--muted)]">4.9/5 on App Store</span>
          <span className="hidden sm:block text-[var(--border)]">·</span>
          <span className="hidden sm:block text-xs font-semibold text-primary px-3 py-1 rounded-full border border-primary">
            Theologically Sound · Orthodox Christian
          </span>
        </div>
        <AnimatePresence mode="wait">
          <motion.div
            key={idx}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.4 }}
          >
            <p className="text-sm text-[var(--muted)] italic text-center sm:text-right max-w-sm">
              {verses[idx]}
            </p>
          </motion.div>
        </AnimatePresence>
      </div>
    </motion.div>
  );
}
