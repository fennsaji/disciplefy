// marketing/components/blog/BlogList.tsx
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { PostCard } from "@/components/blog/PostCard";
import { BlogFilters } from "@/components/blog/BlogFilters";
import { Link } from "@/lib/navigation";
import type { PostMeta, Pagination } from "@/lib/blog";

export function BlogList({
  posts,
  pagination,
  basePath,
  tag,
  query,
  tags,
}: {
  posts: PostMeta[];
  pagination: Pagination;
  basePath: string;
  tag?: string;
  query?: string;
  tags: string[];
}) {
  return (
    <>
      <Navbar />
      <main>
        {/* Hero */}
        <section className="relative overflow-hidden border-b border-[var(--border)] bg-[var(--surface)]">
          <div className="absolute inset-0 bg-gradient-to-br from-primary/5 via-transparent to-violet-500/5 pointer-events-none" />
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 relative">
            <p className="text-xs font-semibold uppercase tracking-widest text-primary dark:text-indigo-300 mb-3">
              Disciplefy Blog
            </p>
            <h1 className="font-display font-extrabold text-4xl sm:text-5xl lg:text-6xl mb-4 bg-gradient-to-r from-[var(--text)] to-[var(--muted)] bg-clip-text text-transparent">
              Grow Deeper<br className="hidden sm:block" /> in Scripture
            </h1>
            <p className="text-[var(--muted)] text-lg max-w-xl">
              Bible study guides, devotionals &amp; theological insights — in English, Hindi &amp; Malayalam.
            </p>
            {pagination.total > 0 && (
              <p className="mt-4 text-sm text-[var(--muted)]">
                {pagination.total} {pagination.total === 1 ? "article" : "articles"} published
              </p>
            )}
          </div>
        </section>

        {/* Posts grid */}
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16">
          <BlogFilters tags={tags} activeTag={tag} query={query} />

          {posts.length === 0 ? (
            <div className="text-center py-20">
              <p className="text-[var(--muted)] text-lg">
                {query ? `No results for "${query}"` : "No posts yet. Check back soon."}
              </p>
            </div>
          ) : (
            <>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {posts.map((post) => (
                  <PostCard key={post.slug} post={post} />
                ))}
              </div>

              {pagination.total_pages > 1 && (
                <div className="flex justify-center gap-2 mt-12">
                  {Array.from({ length: pagination.total_pages }, (_, i) => i + 1).map((p) => (
                    <Link
                      key={p}
                      href={`${basePath}?page=${p}${tag ? `&tag=${tag}` : ""}${query ? `&q=${encodeURIComponent(query)}` : ""}`}
                      className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                        p === pagination.page
                          ? "bg-primary text-white"
                          : "bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)] hover:text-[var(--text)] hover:border-primary/30"
                      }`}
                    >
                      {p}
                    </Link>
                  ))}
                </div>
              )}
            </>
          )}
        </section>
      </main>
      <Footer />
    </>
  );
}
