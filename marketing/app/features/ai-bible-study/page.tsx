// marketing/app/features/ai-bible-study/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "AI Bible Study Guide App — Disciplefy",
  description:
    "Get instant, personalised Bible study guides powered by AI. Study any verse or topic in English, Hindi, or Malayalam.",
  alternates: getAlternates("/features/ai-bible-study"),
  openGraph: {
    images: [{
      url: `/og?title=AI+Bible+Study&subtitle=Instant+Personalised+Study+Guides`,
      width: 1200,
      height: 630,
      alt: "AI Bible Study Guide App — Disciplefy",
    }],
  },
};

export default function AiBibleStudyPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages}>
      <FeaturePageContent
        title="AI Bible Study Guide App"
        description="Get instant, personalised Bible study guides powered by AI. Study any verse or topic in English, Hindi, or Malayalam."
        howItWorks={[
          "Enter a Bible verse reference like John 3:16 or a spiritual question",
          "AI generates a complete study guide — context, interpretation, and life application — in seconds",
          "Read, save to your library, and share guides with others",
        ]}
        downloadCta="Download Free on Android"
        relatedFeatures={[
          { href: "/features/daily-verse", label: "Daily Verse" },
          { href: "/features/study-guides", label: "Study Guides" },
          { href: "/features/fellowship", label: "Fellowship" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
