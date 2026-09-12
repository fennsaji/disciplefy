// Generic "get the app" landing page, served at go.disciplefy.in/download
// (see middleware.ts).
//
// Unlike the other /go pages, this one carries no specific content to open —
// there is no in-app screen a "download" link deep-links into — so it skips
// OpenInApp's intent:// resolution (which only works for a path the app
// itself has a registered App Link for) and just offers the three real
// destinations directly, the same choice links.disciplefy.in gives, styled
// to match the rest of the go.* pages.
import type { Metadata } from "next";
import { Wordmark } from "@/components/go/Wordmark";
import {
  APP_STORE_ID,
  APP_STORE_URL,
  PLAY_STORE_URL,
  WEB_APP_URL,
} from "@/lib/app-links";

export const dynamic = "force-static";

export const metadata: Metadata = {
  title: "Get Disciplefy",
  description:
    "AI-powered Bible study guides in English, Hindi and Malayalam. Get the app for Android or iOS, or use it in your browser.",
  alternates: { canonical: "https://go.disciplefy.in/download" },
  openGraph: {
    title: "Get Disciplefy",
    description: "AI-powered Bible study guides — English · हिन्दी · മലയാളം",
    images: [{ url: "/og?title=Get%20Disciplefy" }],
  },
  twitter: { card: "summary_large_image", title: "Get Disciplefy" },
  itunes: { appId: APP_STORE_ID },
};

const BUTTON =
  "flex h-12 w-full items-center justify-center rounded-lg text-[15px] font-semibold transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#8B84F0]";

export default function DownloadPage() {
  return (
    <main className="flex min-h-screen flex-col items-center bg-[#0F172A] px-6 pb-16 pt-12 sm:pt-16">
      <div className="w-full max-w-[26rem]">
        <div className="flex justify-center">
          <Wordmark />
        </div>

        <h1 className="mt-8 text-center text-[22px] font-semibold leading-snug text-[#E9EDF6]">
          Get Disciplefy
        </h1>
        <p className="mt-3 text-center text-[15px] leading-[1.6] text-[#94A2BD]">
          AI-powered Bible study guides — English · हिन्दी · മലയാളം
        </p>

        <div className="mt-9 flex flex-col gap-3">
          <a
            href={PLAY_STORE_URL}
            className={`${BUTTON} bg-[#5B4FE9] text-white hover:bg-[#4B41CC]`}
          >
            Get it on Google Play
          </a>
          {APP_STORE_URL && (
            <a
              href={APP_STORE_URL}
              className={`${BUTTON} bg-white text-[#0F172A] hover:bg-[#E9EDF6]`}
            >
              Get it on the App Store
            </a>
          )}
          <a
            href={WEB_APP_URL}
            className={`${BUTTON} border border-[#2E3D5F] text-[#C7D2E6] hover:border-[#5B4FE9] hover:text-[#E9EDF6]`}
          >
            Use it in your browser
          </a>
        </div>
      </div>
    </main>
  );
}
