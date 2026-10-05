// marketing/app/links/page.tsx
// Link-in-bio page. Served at links.disciplefy.in (see middleware.ts) and /links.
// Statically rendered: the device-aware download button is chosen in the
// browser before first paint (see lib/link-platform.ts), never on the server.
import type { Metadata } from "next";
import { LinksPage } from "@/components/links/LinksPage";

export const dynamic = "force-static";

export const metadata: Metadata = {
  title: "Disciplefy — All Links",
  description: "Download the Disciplefy app, follow along, or get in touch.",
  alternates: { canonical: "https://links.disciplefy.in/" },
  openGraph: {
    images: [{ url: "https://www.disciplefy.in/og-default.png", width: 1200, height: 630 }],
  },
};

export default function Page() {
  return <LinksPage />;
}
