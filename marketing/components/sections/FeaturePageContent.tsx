// marketing/components/sections/FeaturePageContent.tsx
"use client";
import { motion } from "framer-motion";
import Link from "next/link";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

interface RelatedFeature {
  href: string;
  label: string;
}

interface FeaturePageProps {
  title: string;
  description: string;
  howItWorks: string[];
  downloadCta: string;
  relatedFeatures: RelatedFeature[];
}

export function FeaturePageContent({
  title,
  description,
  howItWorks,
  downloadCta,
  relatedFeatures,
}: FeaturePageProps) {
  return (
    <>
      <Navbar />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="font-display font-extrabold text-4xl sm:text-5xl mb-4"
        >
          {title}
        </motion.h1>
        <motion.p
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.08 }}
          className="text-[var(--muted)] text-lg mb-12"
        >
          {description}
        </motion.p>

        <motion.section
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.4 }}
          className="mb-12"
        >
          <h2 className="font-display font-bold text-2xl mb-6 text-primary">How It Works</h2>
          <ol className="space-y-5">
            {howItWorks.map((step, i) => (
              <li key={i} className="flex items-start gap-4">
                <span className="w-8 h-8 rounded-full bg-primary text-white flex items-center justify-center font-bold text-sm shrink-0 mt-0.5">
                  {i + 1}
                </span>
                <span className="text-[var(--muted)] leading-relaxed pt-1">{step}</span>
              </li>
            ))}
          </ol>
        </motion.section>

        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.4 }}
          className="mb-14"
        >
          <Link
            href="/download"
            className="inline-flex items-center gap-2 bg-primary text-white px-5 py-3 rounded-xl text-sm font-semibold hover:bg-primary/90 transition-colors shadow-md shadow-primary/25"
          >
            {downloadCta}
          </Link>
        </motion.div>

        {relatedFeatures.length > 0 && (
          <motion.nav
            aria-label="Related features"
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.4 }}
          >
            <h3 className="font-display font-semibold text-lg mb-3">Explore Other Features</h3>
            <ul className="flex flex-wrap gap-2">
              {relatedFeatures.map((f) => (
                <li key={f.href}>
                  <Link
                    href={f.href}
                    className="px-4 py-2 rounded-lg border border-[var(--border)] text-sm hover:bg-[var(--surface)] transition-colors"
                  >
                    {f.label}
                  </Link>
                </li>
              ))}
            </ul>
          </motion.nav>
        )}
      </main>
      <Footer />
    </>
  );
}
