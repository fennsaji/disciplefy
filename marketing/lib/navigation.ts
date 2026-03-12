// marketing/lib/navigation.ts
import { createNavigation } from "next-intl/navigation";
import { locales, defaultLocale } from "@/i18n";

// Use these locale-aware hooks instead of next/navigation throughout the app
export const { Link, redirect, usePathname, useRouter } = createNavigation({
  locales,
  defaultLocale,
  localePrefix: "as-needed",
});
