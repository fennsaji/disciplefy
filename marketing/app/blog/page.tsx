// marketing/app/blog/page.tsx
// Fallback for /blog when middleware doesn't rewrite to /[locale]/blog.
// Must wrap with NextIntlClientProvider so Navbar/Footer useTranslations works.
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { BlogList } from "@/components/blog/BlogList";
import { getAllPosts, searchPosts, getTags, getLearningPaths } from "@/lib/blog";
import { getAlternates } from "@/lib/seo";
import messages from "@/messages/en.json";

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
  searchParams: { page?: string; tag?: string; q?: string; learning_path?: string };
}) {
  const page = Math.max(1, parseInt(searchParams.page || "1", 10) || 1);
  const query = searchParams.q?.trim() || undefined;

  const [{ posts, pagination }, tags, learningPaths] = await Promise.all([
    query
      ? searchPosts(query, "en").then((p) => ({
          posts: p,
          pagination: { page: 1, limit: p.length, total: p.length, total_pages: 1, has_more: false },
        }))
      : getAllPosts("en", page, 12, searchParams.tag, searchParams.learning_path),
    getTags("en"),
    getLearningPaths("en"),
  ]);

  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <BlogList
        posts={posts}
        pagination={pagination}
        basePath="/blog"
        tag={searchParams.tag}
        query={query}
        tags={tags}
        locale="en"
        learningPaths={learningPaths}
        activeLearningPath={searchParams.learning_path}
      />
    </NextIntlClientProvider>
  );
}
