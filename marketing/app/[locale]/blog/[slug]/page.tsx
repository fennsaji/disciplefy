// marketing/app/[locale]/blog/[slug]/page.tsx
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { BlogPostContent } from "@/components/blog/BlogPostContent";
import { getPost } from "@/lib/blog";
import { type Locale } from "@/i18n";
import { getAlternates, getBlogPostingJsonLd, getBreadcrumbJsonLd } from "@/lib/seo";

export async function generateMetadata({
  params,
}: {
  params: { locale: Locale; slug: string };
}): Promise<Metadata> {
  const post = await getPost(params.slug);
  if (!post) return {};
  return {
    title: `${post.title} — Disciplefy`,
    description: post.excerpt,
    alternates: getAlternates(`/blog/${params.slug}`),
    openGraph: {
      images: [{
        url: `/og?title=${encodeURIComponent(post.title)}&subtitle=Disciplefy Blog`,
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

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(getBlogPostingJsonLd(post, params.locale)) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(getBreadcrumbJsonLd(post, params.locale)) }}
      />
      <BlogPostContent post={post} locale={params.locale} />
    </>
  );
}
