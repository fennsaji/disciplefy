// marketing/app/blog/[slug]/page.tsx
// Fallback for /blog/[slug] when middleware doesn't rewrite to /[locale]/blog/[slug].
// Must wrap with NextIntlClientProvider so Navbar/Footer useTranslations works.
export const dynamic = "force-dynamic";

import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { BlogPostContent } from "@/components/blog/BlogPostContent";
import { getPost, getAdjacentPosts } from "@/lib/blog";
import messages from "@/messages/en.json";

export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const post = await getPost(params.slug);
  if (!post) return {};
  const postLocale = post.locale ?? "en";
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

export default async function BlogPostPage({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug);
  if (!post) notFound();

  const adjacent = await getAdjacentPosts(params.slug);

  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <BlogPostContent post={post} adjacent={adjacent} />
    </NextIntlClientProvider>
  );
}
