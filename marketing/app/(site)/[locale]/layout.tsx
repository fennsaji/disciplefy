// marketing/app/(site)/[locale]/layout.tsx
// Root layout for every localised route. Owns <html lang={locale}> so the
// language attribute is correct without any request-scoped call above it.
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { NextIntlClientProvider } from "next-intl";
import { ThemeProvider } from "next-themes";
import { Analytics } from "@vercel/analytics/react";
import { SpeedInsights } from "@vercel/speed-insights/next";
import { NavigationProgress } from "@/components/ui/NavigationProgress";
import { CookieConsent } from "@/components/ui/CookieConsent";
import { inter, poppins, notoDevanagari, notoMalayalam } from "@/lib/fonts";
import { getAlternates, homepageJsonLd } from "@/lib/seo";
import { unstable_setRequestLocale } from "next-intl/server";
import { locales, type Locale } from "@/i18n";
import "../../globals.css";

export const metadata: Metadata = {
  title: "Disciplefy — Bible Study in English, Hindi & Malayalam",
  description:
    "Study the Bible deeper with study guides in your language. Free to download.",
  metadataBase: new URL("https://www.disciplefy.in"),
  alternates: getAlternates("/"),
  openGraph: {
    siteName: "Disciplefy",
    locale: "en_IN",
    images: [
      {
        url: "/og?title=Disciplefy&subtitle=Bible Study in Your Language",
        width: 1200,
        height: 675,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    site: "@disciplefy",
    creator: "@disciplefy",
  },
  icons: {
    icon: "/favicon.ico",
    shortcut: "/favicon.ico",
    apple: "/favicon.ico",
  },
};

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export default async function LocaleRootLayout({
  children,
  params: { locale },
}: {
  children: React.ReactNode;
  params: { locale: string };
}) {
  if (!locales.includes(locale as Locale)) notFound();
  unstable_setRequestLocale(locale);

  const messages = (await import(`@/messages/${locale}.json`)).default;

  return (
    <html
      lang={locale}
      suppressHydrationWarning
      className={`${inter.variable} ${poppins.variable} ${notoDevanagari.variable} ${notoMalayalam.variable}`}
    >
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(homepageJsonLd) }}
        />
      </head>
      <body>
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          storageKey="disciplefy-theme"
        >
          <NavigationProgress />
          <NextIntlClientProvider locale={locale} messages={messages}>
            {children}
            <CookieConsent />
          </NextIntlClientProvider>
          <Analytics />
          <SpeedInsights />
        </ThemeProvider>
      </body>
    </html>
  );
}
