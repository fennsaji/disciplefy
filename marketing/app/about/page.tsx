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
  openGraph: {
    images: [{
      url: `/og?title=About+Disciplefy&subtitle=Our+Mission`,
      width: 1200,
      height: 630,
      alt: "About Disciplefy — Our Mission",
    }],
  },
};

export default function AboutPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <AboutPageContent />
    </NextIntlClientProvider>
  );
}
