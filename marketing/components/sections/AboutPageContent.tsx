// marketing/components/sections/AboutPageContent.tsx
"use client";
import { motion } from "framer-motion";
import { useTranslations } from "next-intl";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

export function AboutPageContent() {
  const t = useTranslations("about");

  const sections = [
    {
      title: t("mission.title"),
      content: [t("mission.content")],
    },
    {
      title: t("vision.title"),
      content: [t("vision.content")],
    },
    {
      title: t("theology.title"),
      content: [t("theology.p1"), t("theology.p2")],
    },
    {
      title: t("technology.title"),
      content: [t("technology.content")],
    },
  ];

  return (
    <>
      <Navbar />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="font-display font-extrabold text-4xl sm:text-5xl mb-8"
        >
          {t("title")}
        </motion.h1>

        {sections.map((section, index) => (
          <motion.section
            key={section.title}
            initial={{ opacity: 0, y: 25 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-50px" }}
            transition={{ duration: 0.5, delay: index * 0.08 }}
            className="mb-12"
          >
            <h2 className="font-display font-bold text-2xl mb-4 text-primary">{section.title}</h2>
            {section.content.map((paragraph, pIdx) => (
              <p
                key={pIdx}
                className={`text-[var(--muted)] leading-relaxed ${
                  index === 0 ? "text-lg" : ""
                } ${pIdx < section.content.length - 1 ? "mb-4" : ""}`}
              >
                {paragraph}
              </p>
            ))}
          </motion.section>
        ))}

        <motion.section
          initial={{ opacity: 0, y: 25 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-50px" }}
          transition={{ duration: 0.5, delay: 0.32 }}
        >
          <h2 className="font-display font-bold text-2xl mb-4 text-primary">{t("contact.title")}</h2>
          <p className="text-[var(--muted)]">
            {t("contact.text")}{" "}
            <a href="mailto:hello@disciplefy.in" className="text-primary underline">
              hello@disciplefy.in
            </a>
          </p>
        </motion.section>
      </main>
      <Footer />
    </>
  );
}
