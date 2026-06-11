// marketing/app/[locale]/paths/page.tsx
// Force SSR so the path list is never pre-built with stale API data.
export const dynamic = "force-dynamic";

import type { Metadata } from "next";
import { PathsList } from "@/components/blog/PathsList";
import { getLearningPaths } from "@/lib/blog";
import { type Locale } from "@/i18n";
import { getAlternates } from "@/lib/seo";

export async function generateMetadata({
  params,
}: {
  params: { locale: string };
}): Promise<Metadata> {
  return {
    title: "Learning Paths — Disciplefy",
    description:
      "Structured Bible study journeys. Browse learning paths and read every article in each, in order — in English, Hindi & Malayalam.",
    alternates: getAlternates("/paths", params.locale),
    openGraph: {
      title: "Learning Paths — Disciplefy",
      description:
        "Structured Bible study journeys. Browse learning paths and read every article in each, in order.",
      type: "website",
    },
  };
}

export default async function LocalePathsPage({
  params,
}: {
  params: { locale: Locale };
}) {
  const paths = await getLearningPaths(params.locale);
  return <PathsList paths={paths} locale={params.locale} />;
}
