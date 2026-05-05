// marketing/app/[locale]/blog/[slug]/page.tsx
// Force SSR so newly published posts are immediately visible.
export const dynamic = "force-dynamic";

import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { BlogPostContent } from "@/components/blog/BlogPostContent";
import { getPost, getAdjacentPosts } from "@/lib/blog";
import { type Locale } from "@/i18n";

export async function generateMetadata({
  params,
}: {
  params: { locale: Locale; slug: string };
}): Promise<Metadata> {
  const post = await getPost(params.slug);
  if (!post) return {};
  // Canonical always points to the post's own locale URL.
  // Blog posts are single-locale content — no cross-locale hreflang needed.
  const postLocale = post.locale ?? params.locale;
  const canonicalPrefix = postLocale === "en" ? "" : `/${postLocale}`;
  return {
    title: `${post.title} | Bible Study — Disciplefy`,
    description: post.excerpt,
    keywords: post.tags,
    alternates: { canonical: `https://www.disciplefy.in${canonicalPrefix}/blog/${params.slug}` },
    openGraph: {
      title: `${post.title} | Disciplefy`,
      description: post.excerpt,
      type: "article",
      publishedTime: post.published_at ?? undefined,
      authors: [post.author],
      tags: post.tags,
      images: [{
        url: `https://www.disciplefy.in/og?title=${encodeURIComponent(post.title)}&subtitle=Disciplefy+Blog`,
        width: 1200,
        height: 630,
        alt: post.title,
      }],
    },
  };
}

export default async function LocaleBlogPostPage({
  params,
}: {
  params: { locale: Locale; slug: string };
}) {
  const post = await getPost(params.slug);
  if (!post) notFound();

  const adjacent = await getAdjacentPosts(params.slug);

  // URL locale controls site chrome (navbar, footer); blog content stays in its own locale.
  return <BlogPostContent post={post} locale={params.locale} adjacent={adjacent} />;
}
