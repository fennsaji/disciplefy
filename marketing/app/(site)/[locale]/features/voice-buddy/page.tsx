// marketing/app/[locale]/features/voice-buddy/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import SharedPage from "@/app/_pages/features/voice-buddy/page";
import { metadata as baseMetadata } from "@/app/_pages/features/voice-buddy/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/voice-buddy", params.locale) };
}

export default function LocaleVoiceBuddyPage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <SharedPage />;
}
