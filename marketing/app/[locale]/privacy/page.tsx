// marketing/app/[locale]/privacy/page.tsx
import fs from "fs";
import path from "path";
import matter from "gray-matter";
import { MDXRemote } from "next-mdx-remote/rsc";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { mdxComponents } from "@/components/blog/MDXComponents";
import { type Locale } from "@/i18n";

export const metadata = {
  title: "Privacy Policy — Disciplefy",
  description: "How Disciplefy collects, uses, and protects your personal data.",
};

export default async function LocalePrivacyPage({ params }: { params: { locale: Locale } }) {
  const localePath = path.join(process.cwd(), `content/privacy/${params.locale}.mdx`);
  const fallbackPath = path.join(process.cwd(), "content/privacy/en.mdx");
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
