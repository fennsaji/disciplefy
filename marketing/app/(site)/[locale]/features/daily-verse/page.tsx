// marketing/app/[locale]/features/daily-verse/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import SharedPage from "@/app/_pages/features/daily-verse/page";
import { metadata as baseMetadata } from "@/app/_pages/features/daily-verse/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/daily-verse", params.locale) };
}

export default function LocaleDailyVersePage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <SharedPage />;
}
