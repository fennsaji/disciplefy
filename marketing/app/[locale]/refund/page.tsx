// marketing/app/[locale]/refund/page.tsx
import fs from "fs";
import path from "path";
import matter from "gray-matter";
import { MDXRemote } from "next-mdx-remote/rsc";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { mdxComponents } from "@/components/blog/MDXComponents";
import { type Locale } from "@/i18n";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return {
    title: "Cancellation & Refund Policy — Disciplefy",
    description: "Disciplefy's cancellation and refund policy for token purchases.",
    alternates: getAlternates("/refund", params.locale),
  };
}

export default async function LocaleRefundPage({ params }: { params: { locale: Locale } }) {
  const localePath = path.join(process.cwd(), `content/refund/${params.locale}.mdx`);
  const fallbackPath = path.join(process.cwd(), "content/refund/en.mdx");
  const raw = fs.readFileSync(fs.existsSync(localePath) ? localePath : fallbackPath, "utf-8");
  const { content } = matter(raw);
  return (
    <>
      <Navbar />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <MDXRemote source={content} components={mdxComponents} />
      </main>
      <Footer />
    </>
  );
}
