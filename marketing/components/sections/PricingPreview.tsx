"use client";
// marketing/components/sections/PricingPreview.tsx
import { useTranslations } from "next-intl";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/Button";
import { PLANS } from "@/lib/plans";

export function PricingPreview() {
  const t = useTranslations("pricing");

  return (
    <section className="pt-24 pb-12">
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
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {PLANS.map((plan, index) => {
            const price = plan.price_inr === 0 ? "₹0" : `₹${plan.price_inr}`;
            const prev = index > 0 ? PLANS[index - 1] : null;
            const prevFeatureSet = new Set(prev?.marketing_features ?? []);
            const newFeatures = plan.marketing_features.filter((f) => !prevFeatureSet.has(f));

            return (
              <motion.div
                key={plan.plan_code}
                className={`relative flex flex-col p-6 rounded-2xl border transition-all ${
                  plan.is_highlighted
                    ? "border-primary bg-primary/10 shadow-lg shadow-primary/20"
                    : "border-[var(--border)] bg-[var(--surface)]"
                }`}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ duration: 0.5, delay: index * 0.1 }}
                whileHover={{ y: plan.is_highlighted ? -6 : -3, transition: { duration: 0.2 } }}
              >
                {plan.is_highlighted && (
                  <span className="absolute -top-3 left-1/2 -translate-x-1/2 bg-primary text-white text-xs font-bold px-3 py-1 rounded-full">
                    {t("mostPopular")}
                  </span>
                )}
                {plan.badge && (
                  <span className="absolute -top-3 left-1/2 -translate-x-1/2 bg-emerald-600 text-white text-xs font-bold px-3 py-1 rounded-full">
                    {plan.badge}
                  </span>
                )}
                <p className="font-display font-semibold text-lg mb-1">{plan.display_name}</p>
                <p className="text-2xl font-bold text-primary mb-4">
                  {price}<span className="text-sm font-normal text-[var(--muted)]">{t("perMonth")}</span>
                </p>
                <ul className="space-y-1.5 flex-1">
                  {/* "Everything in [prev plan]" row for non-free plans */}
                  {prev && (
                    <li className="text-xs flex items-start gap-1.5 mb-2">
                      <span className="mt-px shrink-0 text-[#D4930A]" aria-hidden="true">✓</span>
                      <span className="text-[var(--muted)] italic">Everything in {prev.display_name}</span>
                    </li>
                  )}
                  {/* New / upgraded features for this plan */}
                  {(prev ? newFeatures : plan.marketing_features).map((f) => (
                    <li key={f} className="text-xs flex items-start gap-1.5">
                      <span className="mt-px shrink-0 text-primary font-bold" aria-hidden="true">✓</span>
                      <span className="text-[var(--text)] font-medium">{f}</span>
                    </li>
                  ))}
                </ul>
              </motion.div>
            );
          })}
        </div>
        <motion.div
          className="text-center mt-8"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: 0.3 }}
        >
          <Button href="/pricing" variant="secondary" size="sm">
            {t("viewFull")}
          </Button>
        </motion.div>
      </div>
    </section>
  );
}
