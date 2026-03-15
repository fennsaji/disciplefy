// marketing/app/features/memory-verses/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getAlternates } from "@/lib/seo";
import { FeaturePageContent } from "@/components/sections/FeaturePageContent";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Bible Memory Verse App — Disciplefy Memory Verses",
  description:
    "Memorize Bible verses using spaced repetition flashcards with audio. Actually retain God's Word in English, Hindi, or Malayalam.",
  alternates: getAlternates("/features/memory-verses"),
  openGraph: {
    images: [{
      url: `/og?title=Memory+Verses&subtitle=Spaced+Repetition+for+God%27s+Word`,
      width: 1200,
      height: 630,
      alt: "Bible Memory Verse App — Disciplefy",
    }],
  },
};

export default function MemoryVersesPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages}>
      <FeaturePageContent
        title="Memory Verses — Actually Memorize God's Word"
        description="Memorize Bible verses using proven spaced repetition — the same technique used by language learners. With audio pronunciation in your language."
        howItWorks={[
          "Save any verse from a study guide or daily verse to your memory list",
          "Practice with fill-in-the-blank and audio flashcards at spaced intervals",
          "Track your streak and build a lasting habit of hiding Scripture in your heart",
        ]}
        downloadCta="Download Free on Android"
        relatedFeatures={[
          { href: "/features/daily-verse", label: "Daily Verse" },
          { href: "/features/ai-bible-study", label: "AI Bible Study" },
          { href: "/features/learning-paths", label: "Learning Paths" },
        ]}
      />
    </NextIntlClientProvider>
  );
}
