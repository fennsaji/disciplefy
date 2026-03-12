// marketing/app/[locale]/blog/[slug]/page.tsx
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { BlogPostContent } from "@/components/blog/BlogPostContent";
import { getPost } from "@/lib/blog";
import { type Locale } from "@/i18n";

export async function generateMetadata({
  params,
}: {
  params: { locale: Locale; slug: string };
}): Promise<Metadata> {
  const post = await getPost(params.slug);
  if (!post) return {};
  return { title: `${post.title} — Disciplefy`, description: post.excerpt };
}

export default async function LocaleBlogPostPage({
  params,
}: {
  params: { locale: Locale; slug: string };
}) {
  const post = await getPost(params.slug);
  if (!post) notFound();

  return <BlogPostContent post={post} locale={params.locale} />;
}
