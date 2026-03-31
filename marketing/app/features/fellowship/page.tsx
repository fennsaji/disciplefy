// marketing/app/features/fellowship/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Christian Fellowship Groups — Study the Bible Together | Disciplefy",
  description:
    "Create or join a fellowship group, schedule Google Meet Bible study sessions, share prayer requests, praise reports, and study notes with your church community.",
  alternates: getAlternates("/features/fellowship"),
  openGraph: {
    images: [{
      url: `/og?title=Fellowship&subtitle=Group+Bible+Study+with+Google+Meet`,
      width: 1200,
      height: 630,
      alt: "Christian Fellowship Groups — Disciplefy",
    }],
  },
};

export default function FellowshipPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <FeaturePageContent
        title="Fellowship — Study the Bible Together"
        description="Create or join a fellowship group and study Scripture with your church community. Mentors can schedule Google Meet sessions, track member progress, and lead group learning paths — while members share prayer requests, praise reports, and study notes in a shared feed."
        howItWorks={[
          "Create a fellowship group or join one using an invite code from your church",
          "Work through the same Bible learning path together and track each other's progress",
          "Post prayer requests, praise reports, questions, and study notes in the group feed",
          "Mentors schedule Google Meet sessions directly from the app — invites sent automatically",
          "React, comment, and encourage one another as you grow in faith together",
        ]}
        downloadCta="Download Free"
        relatedFeatures={[
          { href: "/features/ai-bible-study", label: "AI Bible Study" },
          { href: "/features/learning-paths", label: "Learning Paths" },
          { href: "/features/study-guides", label: "Study Guides" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
