"use client";
// marketing/components/sections/HomeBlogPreview.tsx
import { useLocale } from "next-intl";
import { motion } from "framer-motion";
import { Link } from "@/lib/navigation";
import { PostCard } from "@/components/blog/PostCard";
import type { PostMeta } from "@/lib/blog";

const COPY = {
  en: {
    eyebrow: "From the Blog",
    title: "Grow Deeper",
    titleAccent: "in Scripture",
    subtitle: "Guides, devotionals & theological insights for your faith journey.",
    viewAll: "Explore all articles →",
  },
  hi: {
    eyebrow: "ब्लॉग से",
    title: "पवित्र शास्त्र में",
    titleAccent: "गहरे जाएं",
    subtitle: "विश्वास के सफर के लिए बाइबल गाइड, भक्ति और ईसाई अंतर्दृष्टि।",
    viewAll: "सभी लेख देखें →",
  },
  ml: {
    eyebrow: "ബ്ലോഗിൽ നിന്ന്",
    title: "തിരുവചനത്തിൽ",
    titleAccent: "ആഴത്തിൽ വളരൂ",
    subtitle: "വിശ്വാസ യാത്രക്കുള്ള ബൈബിൾ ഗൈഡുകൾ, ഭക്തി & ദൈവശാസ്ത്ര ഉൾക്കാഴ്ചകൾ.",
    viewAll: "എല്ലാ ലേഖനങ്ങളും കാണൂ →",
  },
};

export function HomeBlogPreview({ posts }: { posts: PostMeta[] }) {
  const locale = useLocale();
  const copy = COPY[locale as keyof typeof COPY] ?? COPY.en;

  if (posts.length === 0) return null;

  return (
    <section className="py-24 bg-[var(--surface)] border-y border-[var(--border)]">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

        {/* Section header */}
        <div className="text-center mb-14">
          <motion.p
            className="text-xs font-semibold uppercase tracking-widest text-primary dark:text-indigo-300 mb-3"
            initial={{ opacity: 0, y: 10 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.4 }}
          >
            {copy.eyebrow}
          </motion.p>
          <motion.h2
            className="font-display font-extrabold text-3xl sm:text-4xl mb-4"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            {copy.title}{" "}
            <span className="bg-gradient-to-r from-primary to-violet-500 bg-clip-text text-transparent">
              {copy.titleAccent}
            </span>
          </motion.h2>
          <motion.p
            className="text-[var(--muted)] text-lg max-w-xl mx-auto"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.1 }}
          >
            {copy.subtitle}
          </motion.p>
        </div>

        {/* Post grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-12">
          {posts.slice(0, 3).map((post, i) => (
            <motion.div
              key={post.slug}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ duration: 0.5, delay: i * 0.1 }}
            >
              <PostCard post={post} />
            </motion.div>
          ))}
        </div>

        {/* View all CTA */}
        <motion.div
          className="text-center"
          initial={{ opacity: 0, y: 10 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.4, delay: 0.3 }}
        >
          <Link
            href="/blog"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-primary/10 dark:bg-indigo-500/15 text-primary dark:text-indigo-300 font-semibold text-sm hover:bg-primary/20 dark:hover:bg-indigo-500/25 transition-colors"
          >
            {copy.viewAll}
          </Link>
        </motion.div>

      </div>
    </section>
  );
}
