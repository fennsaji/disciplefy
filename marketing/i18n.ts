// marketing/i18n.ts
import { getRequestConfig } from "next-intl/server";
import { notFound } from "next/navigation";

export const locales = ["en", "hi", "ml"] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = "en";

// next-intl v3: use `requestLocale` (not `locale`) for App Router compatibility
export default getRequestConfig(async ({ requestLocale }) => {
  const locale = await requestLocale;
  if (!locale || !locales.includes(locale as Locale)) notFound();
  return {
    locale,
    messages: (await import(`./messages/${locale}.json`)).default,
  };
});
