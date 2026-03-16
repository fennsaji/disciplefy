// marketing/app/blog/[slug]/page.tsx
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { BlogPostContent } from "@/components/blog/BlogPostContent";
import { getPost } from "@/lib/blog";
import { getAlternates } from "@/lib/seo";

export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const post = await getPost(params.slug);
  if (!post) return {};
  return {
    title: `${post.title} | Bible Study — Disciplefy`,
    description: post.excerpt,
    keywords: post.tags,
    alternates: getAlternates(`/blog/${params.slug}`),
    openGraph: {
      title: `${post.title} | Disciplefy`,
      description: post.excerpt,
      type: "article",
      publishedTime: post.published_at ?? undefined,
      authors: [post.author],
      tags: post.tags,
      images: [{
        url: `/og?title=${encodeURIComponent(post.title)}&subtitle=Disciplefy Blog`,
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

  return <BlogPostContent post={post} />;
}
