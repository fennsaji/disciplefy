// marketing/app/features/daily-verse/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Bible Verse of the Day App for Android — Disciplefy",
  description:
    "Start every day with a fresh Bible verse and short devotional in your language. Free on Android.",
  alternates: getAlternates("/features/daily-verse"),
  openGraph: {
    images: [{
      url: `https://www.disciplefy.in/og?title=Daily+Bible+Verse&subtitle=Fresh+Devotional+Every+Day`,
      width: 1200,
      height: 630,
      alt: "Bible Verse of the Day App for Android — Disciplefy",
    }],
  },
};

export default function DailyVersePage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <FeaturePageContent
        title="Bible Verse of the Day App"
        description="Start every day with a fresh Bible verse and short devotional in your language. Free on Android."
        howItWorks={[
          "Open the app each morning to receive a new daily verse",
          "Read a short AI-written devotional in English, Hindi, or Malayalam",
          "Save your favourite verses to revisit any time",
        ]}
        downloadCta="Download Free"
        relatedFeatures={[
          { href: "/features/ai-bible-study", label: "AI Bible Study" },
          { href: "/features/study-guides", label: "Study Guides" },
          { href: "/features/fellowship", label: "Fellowship" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
