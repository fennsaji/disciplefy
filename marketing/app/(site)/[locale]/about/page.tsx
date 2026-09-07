// marketing/app/[locale]/about/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import { AboutPageContent } from "@/components/sections/AboutPageContent";
import { metadata as baseMetadata } from "@/app/_pages/about/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/about", params.locale) };
}

export default function LocaleAboutPage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <AboutPageContent />;
}
