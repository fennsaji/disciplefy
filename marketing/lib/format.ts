const LOCALE_MAP: Record<string, string> = {
  en: "en-US",
  hi: "hi-IN",
  ml: "ml-IN",
};

export function formatDate(dateStr: string | null, locale = "en"): string {
  if (!dateStr) return "";
  return new Date(dateStr).toLocaleDateString(LOCALE_MAP[locale] || "en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}
