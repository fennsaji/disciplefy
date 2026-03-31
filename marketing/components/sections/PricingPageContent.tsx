// marketing/components/sections/PricingPageContent.tsx
"use client";
import { motion } from "framer-motion";
import { useTranslations, useLocale } from "next-intl";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { PLANS } from "@/lib/plans";

interface FAQ {
  q: string;
  a: string;
}

export function PricingPageContent({ jsonLd }: { jsonLd: string }) {
  const t = useTranslations("pricingPage");
  const locale = useLocale();
  const downloadHref = locale === "en" ? "/download" : `/${locale}/download`;
  const faqs = t.raw("faqs") as FAQ[];

  return (
    <>
      <Navbar />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: jsonLd }}
      />
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        {/* Header */}
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="font-display font-extrabold text-4xl sm:text-5xl text-center mb-4"
        >
          {t("pageTitle")}
        </motion.h1>
        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.1 }}
          className="text-[var(--muted)] text-center text-lg mb-16"
        >
          {t("pageSubtitle")}
        </motion.p>

        {/* Pricing grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-24">
          {PLANS.map((plan, index) => {
            const prev = index > 0 ? PLANS[index - 1] : null;
            const prevFeatureSet = new Set(prev?.marketing_features ?? []);
            const newFeatures = plan.marketing_features.filter((f) => !prevFeatureSet.has(f));
            const price = plan.price_inr === 0 ? "₹0" : `₹${plan.price_inr}`;

            return (
              <motion.div
                key={plan.plan_code}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ duration: 0.5, delay: index * 0.1 }}
                whileHover={{ y: plan.is_highlighted ? -6 : -3, transition: { duration: 0.2 } }}
                className={`relative flex flex-col rounded-2xl border p-6 ${
                  plan.is_highlighted
                    ? "border-primary bg-primary/10 shadow-xl shadow-primary/20"
                    : "border-[var(--border)] bg-[var(--surface)]"
                }`}
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
                <p className="font-display font-bold text-xl mb-1">{plan.display_name}</p>
                <p className="text-3xl font-extrabold text-primary mb-1">
                  {price}
                  <span className="text-sm font-normal text-[var(--muted)]">{t("perMonth")}</span>
                </p>
                <p className="text-xs text-[var(--muted)] mb-6">{plan.credits_label}</p>

                <ul className="space-y-2 flex-1 mb-8">
                  {/* "Everything in [prev]" row for non-free plans */}
                  {prev && (
                    <li className="flex items-start gap-2 text-sm mb-1">
                      <span className="text-[#D4930A] mt-0.5 shrink-0">✓</span>
                      <span className="text-[var(--muted)] italic">Everything in {prev.display_name}</span>
                    </li>
                  )}
                  {/* New / upgraded features */}
                  {(prev ? newFeatures : plan.marketing_features).map((f) => (
                    <li key={f} className="flex items-start gap-2 text-sm">
                      <span className="text-primary mt-0.5 shrink-0 font-bold">✓</span>
                      <span className="text-[var(--text)] font-medium">{f}</span>
                    </li>
                  ))}
                </ul>

                <a
                  href={downloadHref}
                  className={`block text-center py-3 rounded-xl font-semibold text-sm transition-colors ${
                    plan.is_highlighted
                      ? "bg-primary text-white hover:bg-primary-hover"
                      : "border border-[var(--border)] hover:border-primary text-[var(--text)]"
                  }`}
                >
                  {plan.price_inr === 0 ? t("startFree") : t("getStarted")}
                </a>
              </motion.div>
            );
          })}
        </div>

        {/* FAQ */}
        <div className="max-w-2xl mx-auto">
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="font-display font-bold text-2xl text-center mb-10"
          >
            {t("faqTitle")}
          </motion.h2>
          <div className="space-y-6">
            {faqs.map((faq, index) => (
              <motion.div
                key={faq.q}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-30px" }}
                transition={{ duration: 0.4, delay: index * 0.05 }}
                className="border-b border-[var(--border)] pb-6"
              >
                <p className="font-semibold mb-2">{faq.q}</p>
                <p className="text-sm text-[var(--muted)] leading-relaxed">{faq.a}</p>
              </motion.div>
            ))}
          </div>
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="text-center mt-12"
          >
            <p className="text-sm text-[var(--muted)] mb-4">{t("ctaText")}</p>
            <a
              href={downloadHref}
              className="inline-flex items-center gap-2 bg-primary text-white px-8 py-4 rounded-xl font-semibold hover:bg-primary-hover transition-colors"
            >
              {t("startFreeNoCard")}
            </a>
          </motion.div>
        </div>
      </main>
      <Footer />
    </>
  );
}
