// marketing/app/[locale]/contact/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import SharedPage from "@/app/_pages/contact/page";
import { metadata as baseMetadata } from "@/app/_pages/contact/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/contact", params.locale) };
}

export default function LocaleContactPage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <SharedPage />;
}
