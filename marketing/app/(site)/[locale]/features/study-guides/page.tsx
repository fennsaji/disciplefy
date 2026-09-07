// marketing/app/[locale]/features/study-guides/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import SharedPage from "@/app/_pages/features/study-guides/page";
import { metadata as baseMetadata } from "@/app/_pages/features/study-guides/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/study-guides", params.locale) };
}

export default function LocaleStudyGuidesPage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <SharedPage />;
}
