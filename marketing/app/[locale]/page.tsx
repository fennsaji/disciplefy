// marketing/app/[locale]/page.tsx
// Each locale has its own page component so next-intl generates correct static params per locale.
import { HomePage } from "@/app/_home";
import { getAllPosts } from "@/lib/blog";
import type { Locale } from "@/i18n";

export default async function LocalePage({ params: { locale } }: { params: { locale: Locale } }) {
  const { posts } = await getAllPosts(locale, 1, 3);
  return <HomePage posts={posts} />;
}
