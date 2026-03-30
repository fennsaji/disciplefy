// marketing/app/[locale]/download/page.tsx
export { default } from "@/app/download/page";
import { metadata as baseMetadata } from "@/app/download/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/download", params.locale) };
}
