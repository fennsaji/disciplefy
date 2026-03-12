// marketing/middleware.ts
import createMiddleware from "next-intl/middleware";
import { locales, defaultLocale } from "./i18n";

export default createMiddleware({
  locales,
  defaultLocale,
  localePrefix: "as-needed", // EN served at root /, HI at /hi, ML at /ml
});

export const config = {
  matcher: ["/((?!api|_next|_vercel|.*\\..*).*)"],
};
