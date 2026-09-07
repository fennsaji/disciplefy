// marketing/app/(standalone)/layout.tsx
// Root layout for the routes that sit outside the locale segment: /links and
// the global not-found. English only — no intl provider is needed here.
import type { Metadata } from "next";
import { ThemeProvider } from "next-themes";
import { Analytics } from "@vercel/analytics/react";
import { SpeedInsights } from "@vercel/speed-insights/next";
import { NavigationProgress } from "@/components/ui/NavigationProgress";
import { inter, poppins, notoDevanagari, notoMalayalam } from "@/lib/fonts";
import "../globals.css";

export const metadata: Metadata = {
  title: "Disciplefy — Bible Study in English, Hindi & Malayalam",
  description:
    "Study the Bible deeper with study guides in your language. Free to download.",
  metadataBase: new URL("https://www.disciplefy.in"),
  icons: {
    icon: "/favicon.ico",
    shortcut: "/favicon.ico",
    apple: "/favicon.ico",
  },
};

export default function StandaloneRootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${inter.variable} ${poppins.variable} ${notoDevanagari.variable} ${notoMalayalam.variable}`}
    >
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
          <SpeedInsights />
        </ThemeProvider>
      </body>
    </html>
  );
}
