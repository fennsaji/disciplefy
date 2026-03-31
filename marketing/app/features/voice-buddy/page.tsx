// marketing/app/features/voice-buddy/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "AI Voice Bible Study App — Disciplefy Voice Buddy",
  description:
    "Have real voice conversations about Scripture with your AI Voice Discipler. Ask Bible questions in English, Hindi, or Malayalam.",
  alternates: getAlternates("/features/voice-buddy"),
  openGraph: {
    images: [{
      url: `/og?title=Voice+Buddy&subtitle=Talk+to+Your+AI+Bible+Companion`,
      width: 1200,
      height: 630,
      alt: "AI Voice Bible Study App — Disciplefy",
    }],
  },
};

export default function VoiceBuddyPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <FeaturePageContent
        title="Voice Buddy — Talk About Scripture"
        description="Have real voice conversations about any Bible passage or spiritual question with your AI Voice Discipler. Speaks naturally in English, Hindi, and Malayalam."
        howItWorks={[
          "Tap the microphone and ask any Bible question or name a passage",
          "Your AI Voice Discipler listens and responds naturally in your language",
          "Continue the conversation — ask follow-up questions just like talking to a friend",
        ]}
        downloadCta="Download Free"
        relatedFeatures={[
          { href: "/features/ai-bible-study", label: "AI Bible Study" },
          { href: "/features/daily-verse", label: "Daily Verse" },
          { href: "/features/follow-up-chat", label: "Follow-Up Chat" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
