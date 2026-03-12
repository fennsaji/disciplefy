// marketing/components/blog/BlogPostContent.tsx
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { mdxComponents } from "@/components/blog/MDXComponents";
import { MDXRemote } from "next-mdx-remote/rsc";
import { formatDate } from "@/lib/format";
import { getBlogPostingJsonLd } from "@/lib/seo";
import type { Post } from "@/lib/blog";

export function BlogPostContent({
  post,
  locale = "en",
}: {
  post: Post;
  locale?: string;
}) {
  return (
    <>
      <Navbar />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(getBlogPostingJsonLd(post, locale)),
        }}
      />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        {post.tags[0] && (
          <span className="inline-block text-xs font-semibold text-primary bg-primary/10 px-3 py-1 rounded-full mb-4">
            {post.tags[0]}
          </span>
        )}
        <h1 className="font-display font-extrabold text-4xl mb-4">{post.title}</h1>
        <div className="flex items-center gap-4 text-sm text-[var(--muted)] mb-12">
          <span>{post.author}</span>
          <span>&middot;</span>
          <span>{formatDate(post.published_at, locale)}</span>
          <span>&middot;</span>
          <span>{post.read_time} min read</span>
        </div>
        <article>
          <MDXRemote source={post.content} components={mdxComponents} />
        </article>
      </main>
      <Footer />
    </>
  );
}
