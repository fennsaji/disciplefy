// marketing/app/[locale]/blog/[slug]/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";

// ISR. Without this the route rendered on every request — three API round-trips
// per view (post, adjacent, related) — which is what the Vercel Functions panel
// was showing as the site's single biggest CPU consumer.
//
// Two exports are needed, not one. `revalidate` alone left the route classified
// dynamic; a dynamic segment only becomes cacheable once generateStaticParams
// exists. It returns [] on purpose: nothing is prerendered at build time (so
// builds don't walk the whole post list as the blog grows), and dynamicParams
// renders each slug on first request and caches it from then on.
//
// A day rather than an hour: this window only governs how long an *edit* to an
// existing post takes to appear. A newly published post has no cache entry, so
// it is never served stale — discovery is the blog list's job, which stays on a
// shorter window.
export const revalidate = 86400;
export const dynamicParams = true;

export async function generateStaticParams() {
  return [];
}

import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { BlogPostContent } from "@/components/blog/BlogPostContent";
import { getPost, getAdjacentPosts, getRelatedPosts } from "@/lib/blog";
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
        url: `https://www.disciplefy.in/og-default.png`,
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
  unstable_setRequestLocale(params.locale);
  const post = await getPost(params.slug);
  if (!post) notFound();

  const [adjacent, related] = await Promise.all([
    getAdjacentPosts(params.slug),
    getRelatedPosts(post, (post.locale as Locale) || params.locale),
  ]);

  // URL locale controls site chrome (navbar, footer); blog content stays in its own locale.
  return <BlogPostContent post={post} locale={params.locale} adjacent={adjacent} related={related} />;
}
