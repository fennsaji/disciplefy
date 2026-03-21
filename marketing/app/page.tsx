// marketing/app/page.tsx
// Fallback for root "/" when middleware doesn't rewrite to /[locale].
// Wraps with NextIntlClientProvider so useTranslations works.
import { NextIntlClientProvider } from "next-intl";
import { HomePage } from "./_home";
import messages from "@/messages/en.json";
import { getAllPosts } from "@/lib/blog";

export default async function Page() {
  const { posts } = await getAllPosts("en", 1, 3);
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <HomePage posts={posts} />
    </NextIntlClientProvider>
  );
}
