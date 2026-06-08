// marketing/app/features/ai-bible-study/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Bible Study Guide App — Disciplefy",
  description:
    "Get instant, personalised Bible study guides. Study any verse or topic in English, Hindi, or Malayalam.",
  alternates: getAlternates("/features/ai-bible-study"),
  openGraph: {
    images: [{
      url: `https://www.disciplefy.in/og?title=Bible+Study&subtitle=Instant+Personalised+Study+Guides`,
      width: 1200,
      height: 675,
      alt: "Bible Study Guide App — Disciplefy",
    }],
  },
};

export default function AiBibleStudyPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <FeaturePageContent
        title="Bible Study Guide App"
        description="Get instant, personalised Bible study guides. Study any verse or topic in English, Hindi, or Malayalam."
        howItWorks={[
          "Enter a Bible verse reference like John 3:16 or a spiritual question",
          "Get a complete study guide — context, interpretation, and life application — in seconds",
          "Read, save to your library, and share guides with others",
        ]}
        downloadCta="Download Free"
        relatedFeatures={[
          { href: "/features/daily-verse", label: "Daily Verse" },
          { href: "/features/study-guides", label: "Study Guides" },
          { href: "/features/fellowship", label: "Fellowship" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
