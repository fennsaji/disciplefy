"use client";
// marketing/components/sections/PricingPreview.tsx
import { useTranslations } from "next-intl";
import Link from "next/link";
import { motion } from "framer-motion";

const plans = [
  { key: "free", price: "₹0", highlighted: false },
  { key: "standard", price: "₹79", highlighted: false },
  { key: "plus", price: "₹149", highlighted: true },
  { key: "premium", price: "₹499", highlighted: false },
] as const;

const planLabels: Record<string, string> = {
  free: "Free",
  standard: "Standard",
  plus: "Plus",
  premium: "Premium",
};

export function PricingPreview() {
  const t = useTranslations("pricing");

  return (
    <section className="py-24">
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
        {/* Mobile/tablet: horizontal scroll. Desktop: 4-column grid */}
        <div className="flex gap-4 overflow-x-auto snap-x snap-mandatory pb-4 lg:grid lg:grid-cols-4 lg:overflow-visible lg:snap-none">
          {plans.map(({ key, price, highlighted }, index) => (
            <motion.div
              key={key}
              className={`relative p-6 rounded-2xl border transition-all snap-start shrink-0 w-56 lg:w-auto ${
                highlighted
                  ? "border-primary bg-primary/10 shadow-lg shadow-primary/20"
                  : "border-[var(--border)] bg-[var(--surface)]"
              }`}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ duration: 0.5, delay: index * 0.1 }}
              whileHover={{ y: highlighted ? -6 : -3, transition: { duration: 0.2 } }}
            >
              {highlighted && (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 bg-primary text-white text-xs font-bold px-3 py-1 rounded-full">
                  {t("mostPopular")}
                </span>
              )}
              <p className="font-display font-semibold text-lg mb-1">{planLabels[key]}</p>
              <p className="text-2xl font-bold text-primary">
                {price}<span className="text-sm font-normal text-[var(--muted)]">{t("perMonth")}</span>
              </p>
            </motion.div>
          ))}
        </div>
        <motion.div
          className="text-center mt-8"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: 0.3 }}
        >
          <Link href="/pricing" className="text-primary font-semibold hover:underline text-sm">
            {t("viewFull")}
          </Link>
        </motion.div>
      </div>
    </section>
  );
}
