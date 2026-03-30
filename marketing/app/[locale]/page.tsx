// marketing/app/[locale]/page.tsx
// Each locale has its own page component so next-intl generates correct static params per locale.
import { HomePage } from "@/app/_home";
import { getAllPosts } from "@/lib/blog";
import type { Locale } from "@/i18n";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return {
    title: "Disciplefy — AI Bible Study in English, Hindi & Malayalam",
    description: "Study the Bible deeper with AI-powered study guides in your language. Free to download.",
    alternates: getAlternates("/", params.locale),
  };
}

export default async function LocalePage({ params: { locale } }: { params: { locale: Locale } }) {
  const { posts } = await getAllPosts(locale, 1, 3);
  return <HomePage posts={posts} />;
}
