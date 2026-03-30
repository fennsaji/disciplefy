// marketing/app/[locale]/contact/page.tsx
export { default } from "@/app/contact/page";
import { metadata as baseMetadata } from "@/app/contact/page";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return { ...baseMetadata, alternates: getAlternates("/contact", params.locale) };
}
