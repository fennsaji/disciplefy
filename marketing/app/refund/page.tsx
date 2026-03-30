// marketing/app/refund/page.tsx
import fs from "fs";
import path from "path";
import matter from "gray-matter";
import { MDXRemote } from "next-mdx-remote/rsc";
import { NextIntlClientProvider } from "next-intl";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { mdxComponents } from "@/components/blog/MDXComponents";
import messages from "@/messages/en.json";
import { getAlternates } from "@/lib/seo";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Cancellation & Refund Policy — Disciplefy",
  description: "Disciplefy's cancellation and refund policy for token purchases.",
  alternates: getAlternates("/refund", "en"),
};

export default async function RefundPage() {
  const raw = fs.readFileSync(path.join(process.cwd(), "content/refund/en.mdx"), "utf-8");
  const { content } = matter(raw);
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <Navbar />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <MDXRemote source={content} components={mdxComponents} />
      </main>
      <Footer />
    </NextIntlClientProvider>
  );
}
