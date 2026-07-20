// marketing/middleware.ts
import createMiddleware from "next-intl/middleware";
import { NextResponse, type NextRequest } from "next/server";
import { locales, defaultLocale } from "./i18n";

const intlMiddleware = createMiddleware({
  locales,
  defaultLocale,
  localePrefix: "as-needed", // EN served at root /, HI at /hi, ML at /ml
  localeDetection: false, // Never auto-redirect based on Accept-Language; URL locale always wins
});

export default function middleware(req: NextRequest) {
  // links.disciplefy.in serves the link-in-bio page at its root. This runs
  // before the intl middleware so next-intl never applies locale handling to
  // the subdomain root. Any other path falls through and resolves normally.
  const host = (req.headers.get("host") ?? "").toLowerCase();
  if (host.startsWith("links.") && req.nextUrl.pathname === "/") {
    return NextResponse.rewrite(new URL("/links", req.url));
  }

  // /links is English-only and lives at app/links/page.tsx, NOT under
  // app/[locale]/. Without this bypass the intl middleware rewrites it to
  // /en/links, which has no route and 404s.
  if (req.nextUrl.pathname === "/links") {
    return NextResponse.next();
  }

  return intlMiddleware(req);
}

export const config = {
  matcher: ["/((?!api|og|_next|_vercel|.*\\..*).*)"],
};
