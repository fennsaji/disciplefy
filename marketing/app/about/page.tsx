// marketing/app/about/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { AboutPageContent } from "@/components/sections/AboutPageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "About Disciplefy — Our Mission",
  description: "Built to help Indian Christians understand God's Word in their heart language.",
  alternates: getAlternates("/about"),
};

export default function AboutPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages}>
      <AboutPageContent />
    </NextIntlClientProvider>
  );
}
