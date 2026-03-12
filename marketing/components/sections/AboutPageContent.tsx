// marketing/components/sections/AboutPageContent.tsx
"use client";
import { motion } from "framer-motion";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

const sections = [
  {
    title: "Our Mission",
    content: [
      "We believe every believer deserves to understand God\u2019s Word in their heart language. Disciplefy exists to make deep, meaningful Bible study accessible to every Indian Christian \u2014 in English, Hindi, and Malayalam.",
    ],
  },
  {
    title: "Our Vision",
    content: [
      "To enable every Indian Christian to study Scripture deeply, daily, in the language they think and pray in. We envision a generation of believers who are rooted in God\u2019s Word and equipped to live it out in their communities.",
    ],
  },
  {
    title: "Theological Stance",
    content: [
      "Disciplefy is built on orthodox Protestant Christian theology. All content is reviewed for doctrinal accuracy and follows historical-grammatical interpretation of Scripture. We hold to the foundational truths of the Christian faith as expressed in historic creeds.",
      "We do not replace the local church or its leadership. Disciplefy is a tool to complement your church community, Sunday school, and personal devotional life \u2014 not to substitute them.",
    ],
  },
  {
    title: "The Technology",
    content: [
      "Disciplefy uses AI to generate Bible study content \u2014 summaries, context, interpretation, prayer points, and discussion questions. The AI follows strict theological guidelines and all output is constrained to align with orthodox Christian teaching. The AI assists study; it does not interpret Scripture with authority. That authority belongs to Scripture alone.",
    ],
  },
];

export function AboutPageContent() {
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
          About Disciplefy
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
                  section.title === "Our Mission" ? "text-lg" : ""
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
          <h2 className="font-display font-bold text-2xl mb-4 text-primary">Contact Us</h2>
          <p className="text-[var(--muted)]">
            Questions, partnerships, or feedback:{" "}
            <a href="mailto:hello@disciplefy.in" className="text-primary underline">hello@disciplefy.in</a>
          </p>
        </motion.section>
      </main>
      <Footer />
    </>
  );
}
