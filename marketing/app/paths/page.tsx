// marketing/app/paths/page.tsx
// Fallback for /paths when middleware doesn't rewrite to /[locale]/paths.
// Must wrap with NextIntlClientProvider so Navbar/Footer useTranslations works.
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { PathsList } from "@/components/blog/PathsList";
import { getLearningPaths } from "@/lib/blog";
import { getAlternates } from "@/lib/seo";
import messages from "@/messages/en.json";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Learning Paths — Disciplefy",
  description:
    "Structured Bible study journeys. Browse learning paths and read every article in each, in order — in English, Hindi & Malayalam.",
  alternates: getAlternates("/paths"),
  openGraph: {
    title: "Learning Paths — Disciplefy",
    description:
      "Structured Bible study journeys. Browse learning paths and read every article in each, in order.",
    type: "website",
  },
};

export default async function PathsPage() {
  const paths = await getLearningPaths("en");

  return (
    <NextIntlClientProvider
      locale="en"
      messages={messages as unknown as import("next-intl").AbstractIntlMessages}
    >
      <PathsList paths={paths} locale="en" />
    </NextIntlClientProvider>
  );
}
