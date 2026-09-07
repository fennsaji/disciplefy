// marketing/app/[locale]/pricing/page.tsx
import { unstable_setRequestLocale } from "next-intl/server";
import { PricingPageContent } from "@/components/sections/PricingPageContent";
import { pricingJsonLd } from "@/lib/seo";
import { metadata as baseMetadata } from "@/app/_pages/pricing/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/pricing", params.locale) };
}

export default function LocalePricingPage({ params: { locale } }: { params: { locale: string } }) {
  unstable_setRequestLocale(locale);
  return <PricingPageContent jsonLd={JSON.stringify(pricingJsonLd)} />;
}
