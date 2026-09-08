"use client";

import { useEffect, useState } from "react";
import {
  androidIntentUrl,
  platformFromUserAgent,
  storeUrlFor,
  type StorePlatform,
} from "@/lib/app-links";

/**
 * Actions on a shared link's landing page, pinned to the bottom of the screen.
 *
 * A shared post can run past one screen, which pushed the action below the
 * fold — the one thing the page exists to offer. Pinning keeps it in reach
 * however long the post is.
 *
 * Opening the app is a plain navigation. On Android that is an `intent://`
 * URL, which opens the app when installed and falls back to Play when it is
 * not. iOS has no equivalent: a Universal Link opens the app when installed
 * and otherwise loads the URL in Safari, so the store link carries that case.
 *
 * No automatic redirect: an in-app browser cannot be detected reliably, and a
 * failed redirect strands the reader on a blank page.
 */
export function OpenInApp({ appUrl }: { appUrl: string }) {
  const [platform, setPlatform] = useState<StorePlatform>("other");

  useEffect(() => {
    setPlatform(
      platformFromUserAgent(navigator.userAgent, navigator.maxTouchPoints > 1),
    );
  }, []);

  const storeUrl = storeUrlFor(platform);
  const storeLabel =
    platform === "ios" ? "Get it on the App Store" : "Get it on Google Play";
  const openUrl = platform === "android" ? androidIntentUrl(appUrl) : appUrl;

  return (
    <div className="fixed inset-x-0 bottom-0 border-t border-[#22304E] bg-[#0F172A]/95 backdrop-blur-sm">
      <div
        className="mx-auto w-full max-w-[34rem] px-6 pt-4"
        style={{ paddingBottom: "calc(1rem + env(safe-area-inset-bottom))" }}
      >
        <a
          href={openUrl}
          className="flex h-12 w-full items-center justify-center rounded-lg bg-[#5B4FE9] font-display text-[15px] font-semibold text-white transition-colors hover:bg-[#4B41CC] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#8B84F0]"
        >
          Open in Disciplefy
        </a>

        <div className="mt-3 flex flex-wrap items-center gap-x-5 gap-y-1 text-[13px] text-[#94A2BD]">
          {storeUrl && (
            <a
              href={storeUrl}
              className="underline decoration-[#2E3D5F] underline-offset-4 transition-colors hover:text-[#E9EDF6] hover:decoration-[#5B4FE9] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#8B84F0]"
            >
              {storeLabel}
            </a>
          )}
          <a
            href={appUrl}
            className="underline decoration-[#2E3D5F] underline-offset-4 transition-colors hover:text-[#E9EDF6] hover:decoration-[#5B4FE9] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#8B84F0]"
          >
            Read on the web
          </a>
        </div>
      </div>
    </div>
  );
}
