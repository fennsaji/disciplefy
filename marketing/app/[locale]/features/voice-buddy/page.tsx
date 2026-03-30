// marketing/app/[locale]/features/voice-buddy/page.tsx
export { default } from "@/app/features/voice-buddy/page";
import { metadata as baseMetadata } from "@/app/features/voice-buddy/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/voice-buddy", params.locale) };
}
