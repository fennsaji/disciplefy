// marketing/app/blog/page.tsx
import type { Metadata } from "next";
import { BlogList } from "@/components/blog/BlogList";
import { getAllPosts, searchPosts, getTags } from "@/lib/blog";
import { getAlternates } from "@/lib/seo";

export const metadata: Metadata = {
  title: "Bible Study Blog — Disciplefy",
  description: "Free Bible study guides, devotionals, and theological insights in English, Hindi & Malayalam. Deepen your faith with AI-powered Scripture exploration.",
  alternates: getAlternates("/blog"),
  openGraph: {
    title: "Bible Study Blog — Disciplefy",
    description: "Free Bible study guides, devotionals, and theological insights in English, Hindi & Malayalam.",
    type: "website",
  },
};

export default async function BlogPage({
  searchParams,
}: {
  searchParams: { page?: string; tag?: string; q?: string };
}) {
  const page = Math.max(1, parseInt(searchParams.page || "1", 10) || 1);
  const query = searchParams.q?.trim() || undefined;

  const [{ posts, pagination }, tags] = await Promise.all([
    query
      ? searchPosts(query, "en").then((p) => ({
          posts: p,
          pagination: { page: 1, limit: p.length, total: p.length, total_pages: 1, has_more: false },
        }))
      : getAllPosts("en", page, 12, searchParams.tag),
    getTags("en"),
  ]);

  return (
    <BlogList
      posts={posts}
      pagination={pagination}
      basePath="/blog"
      tag={searchParams.tag}
      query={query}
      tags={tags}
      locale="en"
    />
  );
}
