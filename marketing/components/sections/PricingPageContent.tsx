// marketing/components/sections/PricingPageContent.tsx
"use client";
import { motion } from "framer-motion";
import { useTranslations } from "next-intl";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

interface PricingPlan {
  name: string;
  price: number;
  tokens: string;
  popular: boolean;
  features: string[];
}

interface FAQ {
  q: string;
  a: string;
}

export function PricingPageContent({ jsonLd }: { jsonLd: string }) {
  const t = useTranslations("pricingPage");
  const plans = t.raw("plans") as PricingPlan[];
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
          {plans.map((plan, index) => (
            <motion.div
              key={plan.name}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ duration: 0.5, delay: index * 0.1 }}
              whileHover={{ y: plan.popular ? -6 : -3, transition: { duration: 0.2 } }}
              className={`relative flex flex-col rounded-2xl border p-6 snap-start shrink-0 w-72 md:w-auto ${
                plan.popular
                  ? "border-primary bg-primary/10 shadow-xl shadow-primary/20"
                  : "border-[var(--border)] bg-[var(--surface)]"
              }`}
            >
              {plan.popular && (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 bg-primary text-white text-xs font-bold px-3 py-1 rounded-full">
                  {t("mostPopular")}
                </span>
              )}
              <p className="font-display font-bold text-xl mb-1">{plan.name}</p>
              <p className="text-3xl font-extrabold text-primary mb-1">
                ₹{plan.price}
                <span className="text-sm font-normal text-[var(--muted)]">{t("perMonth")}</span>
              </p>
              <p className="text-xs text-[var(--muted)] mb-6">{plan.tokens}</p>
              <ul className="space-y-2 flex-1 mb-8">
                {plan.features.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm text-[var(--muted)]">
                    <span className="text-primary mt-0.5">✓</span> {f}
                  </li>
                ))}
              </ul>
              <a
                href="https://app.disciplefy.in"
                className={`block text-center py-3 rounded-xl font-semibold text-sm transition-colors ${
                  plan.popular
                    ? "bg-primary text-white hover:bg-primary-hover"
                    : "border border-[var(--border)] hover:border-primary text-[var(--text)]"
                }`}
              >
                {plan.price === 0 ? t("startFree") : t("getStarted")}
              </a>
            </motion.div>
          ))}
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
              href="https://app.disciplefy.in"
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
