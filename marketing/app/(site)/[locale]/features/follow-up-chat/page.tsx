// marketing/app/[locale]/features/follow-up-chat/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import SharedPage from "@/app/_pages/features/follow-up-chat/page";
import { metadata as baseMetadata } from "@/app/_pages/features/follow-up-chat/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/follow-up-chat", params.locale) };
}

export default function LocaleFollowUpChatPage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <SharedPage />;
}
