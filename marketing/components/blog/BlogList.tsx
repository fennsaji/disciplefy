// marketing/components/blog/BlogList.tsx
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { PostCard } from "@/components/blog/PostCard";
import { BlogFilters } from "@/components/blog/BlogFilters";
import { Link } from "@/lib/navigation";
import type { PostMeta, Pagination } from "@/lib/blog";

const BLOG_HERO: Record<string, {
  tagline: string;
  title: string;
  titleBreak: string;
  subtitle: string;
  article: string;
  articles: string;
  published: string;
  noResults: string;
  noPosts: string;
  viewAllPaths: string;
}> = {
  en: {
    tagline: "Disciplefy Blog",
    title: "Grow Deeper",
    titleBreak: "in Scripture",
    subtitle: "Bible study guides, devotionals & theological insights — in English, Hindi & Malayalam.",
    article: "article",
    articles: "articles",
    published: "published",
    noResults: "No results for",
    noPosts: "No posts yet. Check back soon.",
    viewAllPaths: "Browse Learning Paths",
  },
  hi: {
    tagline: "Disciplefy ब्लॉग",
    title: "पवित्र शास्त्र में",
    titleBreak: "गहरे जाएं",
    subtitle: "बाइबल अध्ययन मार्गदर्शिकाएं, भक्ति और धर्मशास्त्रीय अंतर्दृष्टि — अंग्रेजी, हिंदी और मलयालम में।",
    article: "लेख",
    articles: "लेख",
    published: "प्रकाशित",
    noResults: "कोई परिणाम नहीं",
    noPosts: "अभी कोई पोस्ट नहीं। जल्द वापस देखें।",
    viewAllPaths: "अध्ययन पथ देखें",
  },
  ml: {
    tagline: "Disciplefy ബ്ലോഗ്",
    title: "തിരുവചനത്തിൽ",
    titleBreak: "ആഴത്തിൽ വളരൂ",
    subtitle: "ബൈബിൾ പഠന ഗൈഡുകൾ, ഭക്തി & ദൈവശാസ്ത്ര ഉൾക്കാഴ്ചകൾ — ഇംഗ്ലീഷ്, ഹിന്ദി & മലയാളം.",
    article: "ലേഖനം",
    articles: "ലേഖനങ്ങൾ",
    published: "പ്രസിദ്ധീകരിച്ചത്",
    noResults: "ഫലങ്ങളൊന്നുമില്ല",
    noPosts: "ഇതുവരെ പോസ്റ്റുകളൊന്നുമില്ല. ഉടൻ തിരിച്ചുവരൂ.",
    viewAllPaths: "പഠന പാതകൾ കാണുക",
  },
};

export function BlogList({
  posts,
  pagination,
  basePath,
  tag,
  query,
  tags,
  locale,
  learningPaths,
  activeLearningPath,
}: {
  posts: PostMeta[];
  pagination: Pagination;
  basePath: string;
  tag?: string;
  query?: string;
  tags: string[];
  locale: string;
  learningPaths?: { slug: string; title: string; post_count: number }[];
  activeLearningPath?: string;
}) {
  const hero = BLOG_HERO[locale] ?? BLOG_HERO.en;
  return (
    <>
      <Navbar />
      <main>
        {/* Hero */}
        <section className="relative border-b border-[var(--border)] bg-[var(--surface)]">
          <div className="absolute inset-0 bg-gradient-to-br from-primary/5 via-transparent to-violet-500/5 pointer-events-none" />
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 relative">
            <p className="text-xs font-semibold uppercase tracking-widest text-primary dark:text-indigo-300 mb-3">
              {hero.tagline}
            </p>
            <h1 className="font-display font-extrabold text-4xl sm:text-5xl lg:text-6xl mb-4 bg-gradient-to-r from-[var(--text)] to-[var(--muted)] bg-clip-text text-transparent">
              {hero.title}{hero.titleBreak ? <><br className="hidden sm:block" /> {hero.titleBreak}</> : null}
            </h1>
            <p className="text-[var(--muted)] text-lg max-w-2xl break-words">
              {hero.subtitle}
            </p>
            {pagination.total > 0 && (
              <p className="mt-4 text-sm text-[var(--muted)]">
                {pagination.total} {pagination.total === 1 ? hero.article : hero.articles} {hero.published}
              </p>
            )}
            <div className="mt-6">
              <Link
                href="/paths"
                className="inline-flex items-center gap-2 rounded-xl bg-primary text-white px-5 py-3 text-sm font-semibold hover:bg-primary/90 transition-colors"
              >
                {hero.viewAllPaths}
                <span aria-hidden>→</span>
              </Link>
            </div>
          </div>
        </section>

        {/* Posts grid */}
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <BlogFilters tags={tags} activeTag={tag} query={query} locale={locale} learningPaths={learningPaths} activeLearningPath={activeLearningPath} />

          {posts.length === 0 ? (
            <div className="text-center py-20">
              <p className="text-[var(--muted)] text-lg">
                {query ? `${hero.noResults} "${query}"` : hero.noPosts}
              </p>
            </div>
          ) : (
            <>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {posts.map((post) => (
                  <PostCard key={post.slug} post={post} />
                ))}
              </div>

              {pagination.total_pages > 1 && (() => {
                const qs = (p: number) =>
                  `${basePath}?page=${p}${tag ? `&tag=${tag}` : ""}${query ? `&q=${encodeURIComponent(query)}` : ""}${activeLearningPath ? `&learning_path=${activeLearningPath}` : ""}`;

                const btnClass = "px-3 py-2 rounded-lg text-sm font-medium bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)] hover:text-[var(--text)] hover:border-primary/30 transition-colors";
                const activeClass = "px-3 py-2 rounded-lg text-sm font-medium bg-primary text-white";
                // Show at most 5 page numbers, centered around current page
                const { page: cur, total_pages: total } = pagination;
                const delta = 2;
                let start = Math.max(1, cur - delta);
                let end = Math.min(total, cur + delta);
                if (end - start < delta * 2) {
                  if (start === 1) end = Math.min(total, start + delta * 2);
                  else start = Math.max(1, end - delta * 2);
                }

                const pages: (number | "ellipsis-start" | "ellipsis-end")[] = [];
                if (start > 1) { pages.push(1); if (start > 2) pages.push("ellipsis-start"); }
                for (let i = start; i <= end; i++) pages.push(i);
                if (end < total) { if (end < total - 1) pages.push("ellipsis-end"); pages.push(total); }

                return (
                  <div className="flex justify-center items-center gap-1.5 mt-12">
                    {/* Prev */}
                    {cur > 1 && (
                      <Link href={qs(cur - 1)} className={btnClass} title="Previous">
                        <span aria-hidden="true">&lsaquo;</span>
                      </Link>
                    )}

                    {pages.map((p) =>
                      typeof p === "string" ? (
                        <span key={p} className="px-1 text-[var(--muted)]">&hellip;</span>
                      ) : (
                        <Link key={p} href={qs(p)} className={p === cur ? activeClass : btnClass}>
                          {p}
                        </Link>
                      )
                    )}

                    {/* Next */}
                    {cur < total && (
                      <Link href={qs(cur + 1)} className={btnClass} title="Next">
                        <span aria-hidden="true">&rsaquo;</span>
                      </Link>
                    )}
                  </div>
                );
              })()}
            </>
          )}
        </section>
      </main>
      <Footer />
    </>
  );
}
