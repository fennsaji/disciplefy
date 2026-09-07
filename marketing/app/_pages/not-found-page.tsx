// marketing/app/not-found.tsx
import Link from "next/link";
import { NextIntlClientProvider } from "next-intl";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import messages from "@/messages/en.json";

export default function NotFound() {
  return (
    <NextIntlClientProvider locale="en" messages={messages as unknown as import("next-intl").AbstractIntlMessages}>
      <Navbar />
      <main className="min-h-[60vh] flex items-center justify-center px-4">
        <div className="text-center">
          <p className="text-8xl font-display font-extrabold text-primary/20 mb-4">404</p>
          <h1 className="font-display font-bold text-3xl mb-3">Page Not Found</h1>
          <p className="text-[var(--muted)] mb-8">The page you&apos;re looking for doesn&apos;t exist.</p>
          <Link href="/" className="bg-primary text-white px-6 py-3 rounded-xl font-semibold hover:bg-primary-hover transition-colors">
            Go Home
          </Link>
        </div>
      </main>
      <Footer />
    </NextIntlClientProvider>
  );
}
