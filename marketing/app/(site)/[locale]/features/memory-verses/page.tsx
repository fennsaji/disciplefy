// marketing/app/[locale]/features/memory-verses/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import SharedPage from "@/app/_pages/features/memory-verses/page";
import { metadata as baseMetadata } from "@/app/_pages/features/memory-verses/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/memory-verses", params.locale) };
}

export default function LocaleMemoryVersesPage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <SharedPage />;
}
