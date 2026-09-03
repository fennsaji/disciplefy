// marketing/components/blog/AppDownloadLink.tsx
// Used as the MDX `a` component.
// Play Store / app.disciplefy.in links in article bodies → links.disciplefy.in,
// which lists Android, iOS and web. Rewriting at render time means every
// already-published article picks this up without regeneration.
"use client";
import { type ComponentPropsWithoutRef } from "react";
import { APP_LINKS_URL } from "@/lib/app-links";

function isDownloadHref(href?: string) {
  return (
    (href?.includes("play.google.com") &&
      href.includes("com.disciplefy")) ||
    href === "https://app.disciplefy.in" ||
    href === "https://app.disciplefy.in/"
  );
}

function isAmazonAffiliateHref(href?: string) {
  return href?.startsWith("https://www.amazon.in/") ?? false;
}

export function AppDownloadLink({
  href,
  children,
  ...rest
}: ComponentPropsWithoutRef<"a">) {
  if (isDownloadHref(href)) {
    return (
      <a
        href={APP_LINKS_URL}
        target="_blank"
        rel="noopener noreferrer"
        className="inline-block bg-gradient-to-r from-indigo-500 to-violet-600 text-white text-sm font-semibold px-6 py-2.5 rounded-xl shadow-md hover:shadow-lg hover:opacity-90 transition-all no-underline"
      >
        {children}
      </a>
    );
  }

  if (isAmazonAffiliateHref(href)) {
    return (
      <a
        {...rest}
        href={href}
        target="_blank"
        rel="sponsored nofollow noopener noreferrer"
        className="text-primary dark:text-indigo-300 underline decoration-primary/30 dark:decoration-indigo-400/40 underline-offset-2 hover:decoration-primary dark:hover:decoration-indigo-300 transition-all"
      >
        {children}
      </a>
    );
  }

  // Regular inline link — unchanged styling
  return (
    <a
      href={href}
      className="text-primary dark:text-indigo-300 underline decoration-primary/30 dark:decoration-indigo-400/40 underline-offset-2 hover:decoration-primary dark:hover:decoration-indigo-300 transition-all"
      {...rest}
    >
      {children}
    </a>
  );
}
