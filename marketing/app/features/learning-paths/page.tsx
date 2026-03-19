// marketing/app/features/learning-paths/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Bible Discipleship Learning Paths App — Disciplefy",
  description:
    "Grow in faith with structured discipleship journeys on Grace, Prayer, Faith and more. Step-by-step lessons for Indian Christians.",
  alternates: getAlternates("/features/learning-paths"),
  openGraph: {
    images: [{
      url: `/og?title=Learning+Paths&subtitle=Structured+Discipleship+Journeys`,
      width: 1200,
      height: 630,
      alt: "Bible Discipleship Learning Paths — Disciplefy",
    }],
  },
};

export default function LearningPathsPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <FeaturePageContent
        title="Learning Paths — Grow With Purpose"
        description="Structured discipleship journeys on Grace, Prayer, Faith, and more. Each path walks you through a curated sequence of lessons so you're growing with direction, not just studying random verses."
        howItWorks={[
          "Choose a discipleship journey — Grace, Prayer, Faith, or others",
          "Work through a curated sequence of AI-generated lessons at your own pace",
          "Complete each lesson, track your progress, and move to the next step",
        ]}
        downloadCta="Download Free on Android"
        relatedFeatures={[
          { href: "/features/ai-bible-study", label: "AI Bible Study" },
          { href: "/features/study-guides", label: "Study Guides" },
          { href: "/features/fellowship", label: "Fellowship" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
