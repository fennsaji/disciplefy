// marketing/app/[locale]/pricing/page.tsx
import { PricingPageContent } from "@/components/sections/PricingPageContent";
import { pricingJsonLd } from "@/lib/seo";
import { metadata as baseMetadata } from "@/app/pricing/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/pricing", params.locale) };
}

export default function LocalePricingPage() {
  return <PricingPageContent jsonLd={JSON.stringify(pricingJsonLd)} />;
}
