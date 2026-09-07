// marketing/app/[locale]/features/ai-bible-study/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import SharedPage from "@/app/_pages/features/ai-bible-study/page";
import { metadata as baseMetadata } from "@/app/_pages/features/ai-bible-study/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/ai-bible-study", params.locale) };
}

export default function LocaleAiBibleStudyPage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <SharedPage />;
}
