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

  // go.disciplefy.in is the outbound link host: every shared post and invite
  // points at it. Its paths mirror the app's own (/fellowship/<id>/post/<id>),
  // so the whole path is rewritten under /go, where the server-rendered
  // landing pages live. Done before the intl middleware so a locale prefix is
  // never inserted into a link people have already shared.
  if (host.startsWith("go.")) {
    return NextResponse.rewrite(new URL(`/go${req.nextUrl.pathname}`, req.url));
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
  // Narrowed so the middleware only runs where next-intl actually has work to
  // do. Excluded, in addition to the previous api/og/_next/_vercel/dotted-file
  // exclusions:
  //   - links      -> /links is English-only and lives outside app/[locale]/;
  //                   the in-function bypass below already returned next() for
  //                   it, so skipping the invocation entirely is equivalent.
  //                   (The links.* subdomain still works: that rewrite fires on
  //                   pathname "/", which is still matched.)
  //   - monitoring/ingest style probes are not present in this app, so nothing
  //     else can be excluded without risking a locale rewrite: every other
  //     extension-less path is a real page that next-intl must map to a locale.
  // robots.txt, sitemap.xml and favicon.ico already fall under `.*\..*`.
  //   - go        -> the rewritten path for the go.* link host; those pages
  //                   live outside app/[locale]/ and must not be localised.
  //                   (The go.* rewrite itself fires above on the original
  //                   path, which is still matched.)
  matcher: ["/((?!api|og|links|go|_next|_vercel|.*\\..*).*)"],
};
