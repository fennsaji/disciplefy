// marketing/app/features/follow-up-chat/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Bible Study Follow-Up Chat App — Disciplefy",
  description:
    "Ask deeper questions about any Bible study guide. Your AI keeps the context so every follow-up feels like a natural conversation.",
  alternates: getAlternates("/features/follow-up-chat"),
  openGraph: {
    images: [{
      url: `/og?title=Follow-Up+Chat&subtitle=Ask+Deeper+Bible+Questions`,
      width: 1200,
      height: 630,
      alt: "Bible Study Follow-Up Chat — Disciplefy",
    }],
  },
};

export default function FollowUpChatPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <FeaturePageContent
        title="Follow-Up Chat — Go Deeper"
        description="After reading a study guide, ask any follow-up question you have. The AI remembers the passage and context so you get precise, relevant answers — not generic responses."
        howItWorks={[
          "Open any study guide and tap the chat icon",
          "Ask any question about the passage — application, history, theology, or life",
          "Continue the conversation as long as you need — context is always preserved",
        ]}
        downloadCta="Download Free"
        relatedFeatures={[
          { href: "/features/ai-bible-study", label: "AI Bible Study" },
          { href: "/features/voice-buddy", label: "Voice Buddy" },
          { href: "/features/study-guides", label: "Study Guides" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
