// marketing/app/[locale]/pricing/page.tsx
import { PricingPageContent } from "@/components/sections/PricingPageContent";
import { pricingJsonLd } from "@/lib/seo";

export { metadata } from "@/app/pricing/page";

export default function LocalePricingPage() {
  return <PricingPageContent jsonLd={JSON.stringify(pricingJsonLd)} />;
}
