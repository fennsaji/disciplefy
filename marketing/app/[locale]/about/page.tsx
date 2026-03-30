// marketing/app/[locale]/about/page.tsx
import { AboutPageContent } from "@/components/sections/AboutPageContent";
import { metadata as baseMetadata } from "@/app/about/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/about", params.locale) };
}

export default function LocaleAboutPage() {
  return <AboutPageContent />;
}
