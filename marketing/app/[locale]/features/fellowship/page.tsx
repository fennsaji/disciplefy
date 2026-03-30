// marketing/app/[locale]/features/fellowship/page.tsx
export { default } from "@/app/features/fellowship/page";
import { metadata as baseMetadata } from "@/app/features/fellowship/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/fellowship", params.locale) };
}
