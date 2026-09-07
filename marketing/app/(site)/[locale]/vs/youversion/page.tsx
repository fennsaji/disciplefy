// marketing/app/[locale]/vs/youversion/page.tsx
export { default } from "@/app/vs/youversion/page";
import { metadata as baseMetadata } from "@/app/vs/youversion/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/vs/youversion", params.locale) };
}
