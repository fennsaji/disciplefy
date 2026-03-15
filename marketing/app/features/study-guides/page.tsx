// marketing/app/features/study-guides/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Bible Study Guide App — Free | Disciplefy",
  description:
    "Access AI-generated study guides for any Bible passage. Save, revisit, and grow in your faith. Free on Android.",
  alternates: getAlternates("/features/study-guides"),
  openGraph: {
    images: [{
      url: `/og?title=Study+Guides&subtitle=AI+Generated+for+Any+Passage`,
      width: 1200,
      height: 630,
      alt: "Bible Study Guide App — Free | Disciplefy",
    }],
  },
};

export default function StudyGuidesPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages}>
      <FeaturePageContent
        title="Bible Study Guides — Free & AI-Powered"
        description="Access AI-generated study guides for any Bible passage. Save, revisit, and grow in your faith. Free on Android."
        howItWorks={[
          "Search by Bible passage or spiritual topic",
          "AI generates a full study guide with context, interpretation, and prayer points",
          "Save guides to your personal library to revisit any time",
        ]}
        downloadCta="Download Free on Android"
        relatedFeatures={[
          { href: "/features/ai-bible-study", label: "AI Bible Study" },
          { href: "/features/daily-verse", label: "Daily Verse" },
          { href: "/features/fellowship", label: "Fellowship" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
