// marketing/app/page.tsx
// Fallback for root "/" when middleware doesn't rewrite to /[locale].
// Wraps with NextIntlClientProvider so useTranslations works.
import { NextIntlClientProvider } from "next-intl";
import { HomePage } from "./_home";
import messages from "@/messages/en.json";

export default function Page() {
  return (
    <NextIntlClientProvider locale="en" messages={messages}>
      <HomePage />
    </NextIntlClientProvider>
  );
}
