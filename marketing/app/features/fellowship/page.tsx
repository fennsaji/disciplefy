// marketing/app/features/fellowship/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Christian Group Bible Study App — Disciplefy Fellowship",
  description:
    "Study the Bible together with friends. Share prayer requests and praise reports in your fellowship group.",
  alternates: getAlternates("/features/fellowship"),
  openGraph: {
    images: [{
      url: `/og?title=Fellowship&subtitle=Group+Bible+Study+Together`,
      width: 1200,
      height: 630,
      alt: "Christian Group Bible Study App — Disciplefy Fellowship",
    }],
  },
};

export default function FellowshipPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <FeaturePageContent
        title="Fellowship — Group Bible Study Together"
        description="Study the Bible together with friends and your church community. Share prayer requests and praise reports in your fellowship group."
        howItWorks={[
          "Create a fellowship group or join one from your church",
          "Study the same Bible passage together and share notes",
          "Post prayer requests and praise reports with your group",
        ]}
        downloadCta="Download Free on Android"
        relatedFeatures={[
          { href: "/features/ai-bible-study", label: "AI Bible Study" },
          { href: "/features/daily-verse", label: "Daily Verse" },
          { href: "/features/study-guides", label: "Study Guides" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
