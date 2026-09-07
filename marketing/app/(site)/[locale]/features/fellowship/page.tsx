// marketing/app/[locale]/features/fellowship/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import SharedPage from "@/app/_pages/features/fellowship/page";
import { metadata as baseMetadata } from "@/app/_pages/features/fellowship/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/fellowship", params.locale) };
}

export default function LocaleFellowshipPage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <SharedPage />;
}
