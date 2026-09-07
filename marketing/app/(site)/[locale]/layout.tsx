// marketing/app/[locale]/layout.tsx
// All routes pass through here (next-intl middleware rewrites / → /en, /pricing → /en/pricing, etc.)
// Locale comes from route params — guaranteed correct, never stale.
import { notFound } from "next/navigation";
import { NextIntlClientProvider } from "next-intl";
import { CookieConsent } from "@/components/ui/CookieConsent";
import { locales, type Locale } from "@/i18n";

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export default async function LocaleLayout({
  children,
  params: { locale },
}: {
  children: React.ReactNode;
  params: { locale: string };
}) {
  if (!locales.includes(locale as Locale)) notFound();

  const messages = (await import(`@/messages/${locale}.json`)).default;

  return (
    <NextIntlClientProvider locale={locale} messages={messages}>
      {children}
      <CookieConsent />
    </NextIntlClientProvider>
  );
}
