// marketing/app/[locale]/features/follow-up-chat/page.tsx
export { default } from "@/app/features/follow-up-chat/page";
import { metadata as baseMetadata } from "@/app/features/follow-up-chat/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/features/follow-up-chat", params.locale) };
}
