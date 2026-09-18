// Landing page for a shared daily verse, served at go.disciplefy.in/daily-verse
// (see middleware.ts).
//
// The link carries no specific verse, and the verse text is licensed for the
// app only, so this page does not reproduce it — it offers today's verse in
// the app, which opens to Home. Without it, the link 404'd for anyone without
// the app.
import type { Metadata } from "next";
import { OpenInApp } from "@/components/go/OpenInApp";
import { Wordmark } from "@/components/go/Wordmark";
import { APP_STORE_ID, WEB_APP_URL } from "@/lib/app-links";

export const dynamic = "force-static";

const APP_URL = `${WEB_APP_URL}/daily-verse`;
const TITLE = "Today's verse on Disciplefy";
const DESCRIPTION =
  "A new Bible verse every day in English, Hindi and Malayalam, with a study guide for each.";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  alternates: { canonical: "https://go.disciplefy.in/daily-verse" },
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    images: [{ url: `/og-default.png` }],
  },
  twitter: { card: "summary_large_image", title: TITLE, description: DESCRIPTION },
  itunes: { appId: APP_STORE_ID, appArgument: APP_URL },
};

export default function SharedDailyVersePage() {
  return (
    <main className="min-h-screen bg-[#0F172A] px-6 pb-44 pt-12 sm:pt-16">
      <div className="mx-auto w-full max-w-[34rem]">
        <Wordmark />

        <div className="mt-10 border-l-2 border-[#5B4FE9] pl-5 sm:pl-6">
          <p className="text-[13px] font-medium uppercase tracking-wide text-[#8B84F0]">
            Daily verse
          </p>
          <h1 className="mt-2 text-[22px] font-semibold leading-snug text-[#E9EDF6] sm:text-[26px]">
            {TITLE}
          </h1>
          <p className="mt-3 text-[15.5px] leading-[1.6] text-[#94A2BD]">
            A new verse every day in English, हिन्दी and മലയാളം. Open
            Disciplefy to read today&apos;s verse and study it.
          </p>
        </div>

        <OpenInApp appUrl={APP_URL} />
      </div>
    </main>
  );
}
