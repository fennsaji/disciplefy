// marketing/app/download/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates, downloadPageJsonLd } from "@/lib/seo";
import { DownloadPageContent } from "@/components/sections/DownloadPageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Download Disciplefy — Free Bible Study App",
  description: "Download the free Disciplefy Bible study app. AI-powered study guides in English, Hindi, and Malayalam.",
  alternates: getAlternates("/download"),
  openGraph: {
    images: [{
      url: `https://www.disciplefy.in/og?title=Download+Disciplefy&subtitle=Free+Bible+Study+App`,
      width: 1200,
      height: 630,
      alt: "Download Disciplefy — Free Bible Study App",
    }],
  },
};

export default function DownloadPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <DownloadPageContent jsonLd={JSON.stringify(downloadPageJsonLd)} />
    </NextIntlClientProvider>
  );
}
