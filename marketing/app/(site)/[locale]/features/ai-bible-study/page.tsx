// marketing/app/[locale]/features/ai-bible-study/page.tsx
export { default } from "@/app/features/ai-bible-study/page";
import { metadata as baseMetadata } from "@/app/features/ai-bible-study/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/ai-bible-study", params.locale) };
}
