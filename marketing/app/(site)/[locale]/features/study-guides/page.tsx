// marketing/app/[locale]/features/study-guides/page.tsx
export { default } from "@/app/features/study-guides/page";
import { metadata as baseMetadata } from "@/app/features/study-guides/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/study-guides", params.locale) };
}
