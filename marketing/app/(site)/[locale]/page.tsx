// marketing/app/[locale]/page.tsx
// Each locale has its own page component so next-intl generates correct static params per locale.
import { HomePage } from "@/app/_home";
import { getAllPosts } from "@/lib/blog";
import type { Locale } from "@/i18n";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return {
    title: "Disciplefy — From Believer to Disciple",
    description: "Understand God's Word, grow spiritually, and follow Jesus every day. Free Bible study guides in English, Hindi & Malayalam.",
    alternates: getAlternates("/", params.locale),
  };
}

export default async function LocalePage({ params: { locale } }: { params: { locale: Locale } }) {
  const { posts } = await getAllPosts(locale, 1, 3);
  return <HomePage posts={posts} />;
}
