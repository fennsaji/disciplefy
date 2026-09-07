// marketing/app/[locale]/features/learning-paths/page.tsx
export { default } from "@/app/features/learning-paths/page";
import { metadata as baseMetadata } from "@/app/features/learning-paths/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/learning-paths", params.locale) };
}
