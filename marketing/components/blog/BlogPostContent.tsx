// marketing/components/blog/BlogPostContent.tsx
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { mdxComponents } from "@/components/blog/MDXComponents";
import { ReadingProgress } from "@/components/blog/ReadingProgress";
import { MDXRemote } from "next-mdx-remote/rsc";
import { formatDate } from "@/lib/format";
import { getBlogPostingJsonLd, getBreadcrumbJsonLd } from "@/lib/seo";
import type { Post } from "@/lib/blog";
import { Link } from "@/lib/navigation";

const TAG_GRADIENT: Record<string, string> = {
  foundations:   "from-indigo-500 to-violet-500",
  seeker:        "from-violet-500 to-purple-500",
  prayer:        "from-blue-500 to-indigo-500",
  "bible-study": "from-indigo-500 to-violet-500",
  discipleship:  "from-teal-500 to-indigo-500",
  growth:        "from-emerald-500 to-teal-500",
  theology:      "from-violet-600 to-purple-600",
  devotional:    "from-rose-500 to-pink-500",
};
const DEFAULT_GRADIENT = "from-indigo-500 to-violet-600";

function getGradient(tags: string[]) {
  for (const tag of tags) {
    if (TAG_GRADIENT[tag]) return TAG_GRADIENT[tag];
  }
  return DEFAULT_GRADIENT;
}

export function BlogPostContent({
  post,
  locale = "en",
}: {
  post: Post;
  locale?: string;
}) {
  const gradient = getGradient(post.tags);
  return (
    <>
      <Navbar />

      {/* Structured data */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(getBlogPostingJsonLd(post, locale)) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(getBreadcrumbJsonLd(post, locale)) }}
      />

      {/* Sticky reading progress */}
      <ReadingProgress gradient={gradient} />

      {/* ── Post hero ────────────────────────────────── */}
      <header className="relative overflow-hidden border-b border-[var(--border)]">
        {/* Ambient gradient backdrop */}
        <div className="absolute inset-0 bg-gradient-to-br from-primary/10 via-transparent to-violet-600/10 pointer-events-none" />
        <div className="absolute inset-0 bg-[var(--bg)] opacity-60 pointer-events-none" />

        <div className="relative max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 pt-10 pb-12">
          {/* Breadcrumb */}
          <nav className="flex items-center gap-1.5 text-xs text-[var(--muted)] mb-6" aria-label="Breadcrumb">
            <Link href="/" className="hover:text-primary dark:hover:text-indigo-300 transition-colors">Home</Link>
            <span className="opacity-40">/</span>
            <Link href="/blog" className="hover:text-primary dark:hover:text-indigo-300 transition-colors">Blog</Link>
            <span className="opacity-40">/</span>
            <span className="text-[var(--text)] font-medium truncate max-w-[220px]">{post.title}</span>
          </nav>

          {/* Tags */}
          {post.tags.length > 0 && (
            <div className="flex flex-wrap gap-1.5 mb-5">
              {post.tags.map((tag) => (
                <span
                  key={tag}
                  className="text-xs font-semibold text-primary dark:text-indigo-300 bg-primary/10 dark:bg-indigo-500/15 px-2.5 py-0.5 rounded-full"
                >
                  {tag}
                </span>
              ))}
            </div>
          )}

          {/* Title */}
          <h1 className="font-display font-extrabold text-3xl sm:text-4xl lg:text-5xl leading-tight text-gray-900 dark:text-white mb-6">
            {post.title}
          </h1>

          {/* Meta strip */}
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm">
            <span className="font-semibold text-gray-800 dark:text-slate-200">{post.author}</span>
            <span className="text-gray-400 dark:text-slate-600">·</span>
            <span className="text-gray-500 dark:text-slate-400">{formatDate(post.published_at, locale)}</span>
            <span className="text-gray-400 dark:text-slate-600">·</span>
            <span className="inline-flex items-center gap-1 text-gray-500 dark:text-slate-400">
              <svg className="w-3.5 h-3.5 opacity-70" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              {post.read_time} min read
            </span>
          </div>
        </div>

        {/* Bottom gradient stripe */}
        <div className={`h-[3px] w-full bg-gradient-to-r ${gradient}`} />
      </header>

      {/* ── Article body ─────────────────────────────── */}
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
        <article>
          <MDXRemote source={post.content} components={mdxComponents} />
        </article>

        {/* ── App CTA ──────────────────────────────────── */}
        <div className="mt-16 rounded-2xl overflow-hidden border border-primary/20 dark:border-indigo-500/20">
          <div className={`h-1 bg-gradient-to-r ${gradient}`} />
          <div className="p-6 sm:p-8 bg-primary/5 dark:bg-indigo-500/5 text-center">
            <p className="font-display font-bold text-xl mb-2 text-gray-900 dark:text-white">
              Study this in the Disciplefy app
            </p>
            <p className="text-sm text-gray-500 dark:text-slate-400 mb-5 max-w-md mx-auto">
              Interactive study guides, follow-up chats, practice modes &amp; audio — in English, Hindi &amp; Malayalam.
            </p>
            <a
              href="https://play.google.com/store/apps/details?id=com.disciplefy.bible_study"
              className={`inline-block bg-gradient-to-r ${gradient} text-white text-sm font-semibold px-7 py-3 rounded-xl shadow-md hover:shadow-lg hover:opacity-90 transition-all`}
            >
              Download Free on Android →
            </a>
          </div>
        </div>
      </main>

      <Footer />
    </>
  );
}
