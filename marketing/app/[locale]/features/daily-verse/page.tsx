// marketing/app/[locale]/features/daily-verse/page.tsx
export { default } from "@/app/features/daily-verse/page";
import { metadata as baseMetadata } from "@/app/features/daily-verse/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/daily-verse", params.locale) };
}
