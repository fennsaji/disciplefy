// marketing/app/[locale]/blog/page.tsx
// This page reads searchParams (page/tag/q/learning_path), which already keeps
// it out of static generation — so the old force-dynamic was not what stopped
// it being pre-built with an empty post list.
//
// What force-dynamic *did* do was set fetchCache to force-no-store, which
// silently overrode the revalidate hints in lib/blog.ts and sent every render
// to the API. Dropping it lets the post list come from the data cache for an
// hour while the page still renders per request.

import type { Metadata } from "next";
import { BlogList } from "@/components/blog/BlogList";
import { getAllPosts, searchPosts, getTags, getLearningPaths } from "@/lib/blog";
import { type Locale } from "@/i18n";
import { getAlternates } from "@/lib/seo";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return {
    title: "Bible Study Blog — Disciplefy",
    description: "Free Bible study guides, devotionals, and theological insights in English, Hindi & Malayalam. Deepen your faith with Scripture exploration in your language.",
    alternates: getAlternates("/blog", params.locale),
    openGraph: {
      title: "Bible Study Blog — Disciplefy",
      description: "Free Bible study guides, devotionals, and theological insights in English, Hindi & Malayalam.",
      type: "website",
      images: [{ url: "https://www.disciplefy.in/og-default.png", width: 1200, height: 630 }],
    },
  };
}

export default async function LocaleBlogPage({
  params,
  searchParams,
}: {
  params: { locale: Locale };
  searchParams: { page?: string; tag?: string; q?: string; learning_path?: string };
}) {
  const page = Math.max(1, parseInt(searchParams.page || "1", 10) || 1);
  const query = searchParams.q?.trim() || undefined;

  const [{ posts, pagination }, tags, learningPaths] = await Promise.all([
    query
      ? searchPosts(query, params.locale).then((p) => ({
          posts: p,
          pagination: { page: 1, limit: p.length, total: p.length, total_pages: 1, has_more: false },
        }))
      : getAllPosts(params.locale, page, 12, searchParams.tag, searchParams.learning_path),
    getTags(params.locale),
    getLearningPaths(params.locale),
  ]);

  return (
    <BlogList
      posts={posts}
      pagination={pagination}
      basePath="/blog"
      tag={searchParams.tag}
      query={query}
      tags={tags}
      locale={params.locale}
      learningPaths={learningPaths}
      activeLearningPath={searchParams.learning_path}
    />
  );
}
