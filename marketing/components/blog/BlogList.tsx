// marketing/components/blog/BlogList.tsx
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { PostCard } from "@/components/blog/PostCard";
import { Link } from "@/lib/navigation";
import type { PostMeta, Pagination } from "@/lib/blog";

export function BlogList({
  posts,
  pagination,
  basePath,
  tag,
}: {
  posts: PostMeta[];
  pagination: Pagination;
  basePath: string;
  tag?: string;
}) {
  return (
    <>
      <Navbar />
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <h1 className="font-display font-extrabold text-4xl sm:text-5xl mb-16">Blog</h1>
        {posts.length === 0 ? (
          <p className="text-[var(--muted)]">No posts yet. Check back soon.</p>
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
                    href={`${basePath}?page=${p}${tag ? `&tag=${tag}` : ""}`}
                    className={`px-4 py-2 rounded-lg text-sm ${
                      p === pagination.page
                        ? "bg-primary text-white"
                        : "bg-[var(--surface)] border border-[var(--border)] text-[var(--muted)] hover:text-[var(--text)]"
                    }`}
                  >
                    {p}
                  </Link>
                ))}
              </div>
            )}
          </>
        )}
      </main>
      <Footer />
    </>
  );
}
