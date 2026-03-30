// marketing/app/[locale]/features/memory-verses/page.tsx
export { default } from "@/app/features/memory-verses/page";
import { metadata as baseMetadata } from "@/app/features/memory-verses/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/memory-verses", params.locale) };
}
