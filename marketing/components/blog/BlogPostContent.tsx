// marketing/components/blog/BlogPostContent.tsx
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { mdxComponents } from "@/components/blog/MDXComponents";
import { ReadingProgress } from "@/components/blog/ReadingProgress";
import { BlogPostCTA } from "@/components/blog/BlogPostCTA";
import { MDXRemote } from "next-mdx-remote/rsc";
import { formatDate } from "@/lib/format";
import { getBlogPostingJsonLd, getBreadcrumbJsonLd } from "@/lib/seo";
import type { Post, AdjacentPosts } from "@/lib/blog";
import { Link } from "@/lib/navigation";

// Minimal server-side UI strings — avoids async getTranslations in a server component
// while keeping the component usable from both the locale and fallback routes.
const UI_STRINGS = {
  en: { home: "Home",    blog: "Blog",    minRead: (n: number) => `${n} min read` },
  hi: { home: "होम",     blog: "ब्लॉग",   minRead: (n: number) => `${n} मिनट पढ़ें` },
  ml: { home: "ഹോം",    blog: "ബ്ലോഗ്",  minRead: (n: number) => `${n} മിനിറ്റ് വായന` },
} as const;
type UILocale = keyof typeof UI_STRINGS;

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
  adjacent,
}: {
  post: Post;
  locale?: string;
  adjacent?: AdjacentPosts;
}) {
  const gradient = getGradient(post.tags);
  const ui = UI_STRINGS[(locale as UILocale) in UI_STRINGS ? (locale as UILocale) : "en"];
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
            <Link href="/" className="hover:text-primary dark:hover:text-indigo-300 transition-colors">{ui.home}</Link>
            <span className="opacity-40">/</span>
            <Link href="/blog" className="hover:text-primary dark:hover:text-indigo-300 transition-colors">{ui.blog}</Link>
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

          {/* Learning Path badge */}
          {post.learning_path && (
            <Link
              href={`/blog?learning_path=${post.learning_path.slug}`}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 mb-5 rounded-lg
                         bg-gradient-to-r from-indigo-500/10 to-violet-500/10
                         border border-indigo-500/20 dark:border-indigo-400/20
                         text-sm font-medium text-indigo-700 dark:text-indigo-300
                         hover:border-indigo-500/40 transition-colors"
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4.26 10.147a60.438 60.438 0 0 0-.491 6.347A48.62 48.62 0 0 1 12 20.904a48.62 48.62 0 0 1 8.232-4.41 60.46 60.46 0 0 0-.491-6.347m-15.482 0a50.636 50.636 0 0 0-2.658-.813A59.906 59.906 0 0 1 12 3.493a59.903 59.903 0 0 1 10.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0 1 12 13.489a50.702 50.702 0 0 1 7.74-3.342M6.75 15a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Zm0 0v-3.675A55.378 55.378 0 0 1 12 8.443m-7.007 11.55A5.981 5.981 0 0 0 6.75 15.75v-1.5" />
              </svg>
              {post.learning_path.title}
            </Link>
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
              {ui.minRead(post.read_time)}
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
        <BlogPostCTA gradient={gradient} />

        {/* ── Next / Previous navigation ─────────────── */}
        {adjacent && (adjacent.prev || adjacent.next) && (
          <nav className="mt-12 pt-8 border-t border-[var(--border)] grid grid-cols-1 sm:grid-cols-2 gap-4" aria-label="Post navigation">
            {adjacent.prev ? (
              <Link
                href={`/blog/${adjacent.prev.slug}`}
                className="group flex flex-col gap-1 p-4 rounded-xl border border-[var(--border)] hover:border-primary/40 transition-colors"
              >
                <span className="text-xs font-medium text-[var(--muted)] group-hover:text-primary transition-colors">&larr; Previous</span>
                <span className="text-sm font-semibold text-[var(--text)] line-clamp-2">{adjacent.prev.title}</span>
              </Link>
            ) : (
              <div />
            )}
            {adjacent.next ? (
              <Link
                href={`/blog/${adjacent.next.slug}`}
                className="group flex flex-col gap-1 p-4 rounded-xl border border-[var(--border)] hover:border-primary/40 transition-colors text-right"
              >
                <span className="text-xs font-medium text-[var(--muted)] group-hover:text-primary transition-colors">Next &rarr;</span>
                <span className="text-sm font-semibold text-[var(--text)] line-clamp-2">{adjacent.next.title}</span>
              </Link>
            ) : (
              <div />
            )}
          </nav>
        )}
      </main>

      <Footer />
    </>
  );
}
