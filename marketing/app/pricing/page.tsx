// marketing/app/pricing/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates, pricingJsonLd } from "@/lib/seo";
import { PricingPageContent } from "@/components/sections/PricingPageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Pricing — Disciplefy Bible Study App",
  description: "Simple, affordable plans starting at ₹79/month. Start free.",
  alternates: getAlternates("/pricing"),
};

export default function PricingPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages}>
      <PricingPageContent jsonLd={JSON.stringify(pricingJsonLd)} />
    </NextIntlClientProvider>
  );
}
