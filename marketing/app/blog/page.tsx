// marketing/app/blog/page.tsx
import type { Metadata } from "next";
import { BlogList } from "@/components/blog/BlogList";
import { getAllPosts } from "@/lib/blog";

export const metadata: Metadata = {
  title: "Blog — Disciplefy",
  description: "Devotionals, Bible study tips, and updates from the Disciplefy team.",
};

export default async function BlogPage({
  searchParams,
}: {
  searchParams: { page?: string; tag?: string };
}) {
  const page = Math.max(1, parseInt(searchParams.page || "1", 10) || 1);
  const { posts, pagination } = await getAllPosts("en", page, 12, searchParams.tag);

  return <BlogList posts={posts} pagination={pagination} basePath="/blog" tag={searchParams.tag} />;
}
