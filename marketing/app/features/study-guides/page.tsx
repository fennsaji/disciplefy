// marketing/app/features/study-guides/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Bible Study Guide App — Free | Disciplefy",
  description:
    "Access structured study guides for any Bible passage. Save, revisit, and grow in your faith. Free on Android.",
  alternates: getAlternates("/features/study-guides"),
  openGraph: {
    images: [{
      url: `https://www.disciplefy.in/og?title=Study+Guides&subtitle=Structured+for+Any+Passage`,
      width: 1200,
      height: 675,
      alt: "Bible Study Guide App — Free | Disciplefy",
    }],
  },
};

export default function StudyGuidesPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <FeaturePageContent
        title="Bible Study Guides — Free, In Your Language"
        description="Access structured study guides for any Bible passage. Save, revisit, and grow in your faith. Free on Android."
        howItWorks={[
          "Search by Bible passage or spiritual topic",
          "Get a full study guide with context, interpretation, and prayer points",
          "Save guides to your personal library to revisit any time",
        ]}
        downloadCta="Download Free"
        relatedFeatures={[
          { href: "/features/ai-bible-study", label: "Bible Study" },
          { href: "/features/daily-verse", label: "Daily Verse" },
          { href: "/features/fellowship", label: "Fellowship" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
