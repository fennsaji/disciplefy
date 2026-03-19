// marketing/app/privacy/page.tsx
import fs from "fs";
import path from "path";
import matter from "gray-matter";
import { MDXRemote } from "next-mdx-remote/rsc";
import { NextIntlClientProvider } from "next-intl";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { mdxComponents } from "@/components/blog/MDXComponents";
import messages from "@/messages/en.json";

export const metadata = {
  title: "Privacy Policy — Disciplefy",
  description: "How Disciplefy collects, uses, and protects your personal data.",
};

export default async function PrivacyPage() {
  const raw = fs.readFileSync(path.join(process.cwd(), "content/privacy/en.mdx"), "utf-8");
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
