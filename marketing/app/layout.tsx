// marketing/app/layout.tsx
// Root layout: minimal HTML shell only — locale context is provided by [locale]/layout.tsx
// (moving NextIntlClientProvider to [locale]/layout.tsx ensures locale always matches URL params)
import type { Metadata } from "next";
import { ThemeProvider } from "next-themes";
import { Analytics } from "@vercel/analytics/react";
import { NavigationProgress } from "@/components/ui/NavigationProgress";
import { inter, poppins, notoDevanagari, notoMalayalam } from "@/lib/fonts";
import { getAlternates, homepageJsonLd } from "@/lib/seo";
import { getLocale } from "next-intl/server";
import "./globals.css";

export const metadata: Metadata = {
  title: "Disciplefy — AI Bible Study in English, Hindi & Malayalam",
  description:
    "Study the Bible deeper with AI-powered study guides in your language. Free to download.",
  metadataBase: new URL("https://www.disciplefy.in"),
  alternates: getAlternates("/"),
  openGraph: {
    siteName: "Disciplefy",
    locale: "en_IN",
    images: [
      {
        url: "/og?title=Disciplefy&subtitle=AI Bible Study in Your Language",
        width: 1200,
        height: 630,
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

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const locale = await getLocale().catch(() => "en");
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
          {children}
          <Analytics />
        </ThemeProvider>
      </body>
    </html>
  );
}
