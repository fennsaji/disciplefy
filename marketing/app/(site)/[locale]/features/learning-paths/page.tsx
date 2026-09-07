// marketing/app/[locale]/features/learning-paths/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import SharedPage from "@/app/_pages/features/learning-paths/page";
import { metadata as baseMetadata } from "@/app/_pages/features/learning-paths/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/learning-paths", params.locale) };
}

export default function LocaleLearningPathsPage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <SharedPage />;
}
