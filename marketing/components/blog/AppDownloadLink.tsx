// marketing/components/blog/AppDownloadLink.tsx
// Used as the MDX `a` component.
// Play Store / app.disciplefy.in links → redirect to /download so the user
// can choose between the Android app and the web app themselves.
"use client";
import { type ComponentPropsWithoutRef } from "react";
import { Link } from "@/lib/navigation";

function isDownloadHref(href?: string) {
  return (
    (href?.includes("play.google.com") &&
      href.includes("com.disciplefy")) ||
    href === "https://app.disciplefy.in"
  );
}

export function AppDownloadLink({
  href,
  children,
  ...rest
}: ComponentPropsWithoutRef<"a">) {
  if (isDownloadHref(href)) {
    return (
      <Link
        href="/download"
        className="inline-block bg-gradient-to-r from-indigo-500 to-violet-600 text-white text-sm font-semibold px-6 py-2.5 rounded-xl shadow-md hover:shadow-lg hover:opacity-90 transition-all no-underline"
      >
        {children}
      </Link>
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
