// marketing/app/contact/page.tsx
import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { getAlternates } from "@/lib/seo";
import messages from "@/messages/en.json";

export const metadata: Metadata = {
  title: "Contact Disciplefy — Get in Touch",
  description: "Reach out for support, feedback, partnerships, or privacy inquiries. We're here to help.",
  alternates: getAlternates("/contact"),
};

const contacts = [
  {
    icon: "✉️",
    title: "General Inquiries",
    email: "hello@disciplefy.in",
    description: "Questions, partnerships, or feedback about Disciplefy.",
  },
  {
    icon: "🛠️",
    title: "App Support",
    email: "support@disciplefy.in",
    description: "Having trouble with the app? We'll help you get back on track.",
  },
  {
    icon: "🔒",
    title: "Privacy & Data",
    email: "privacy@disciplefy.in",
    description: "Data deletion requests, privacy concerns, or GDPR inquiries.",
  },
  {
    icon: "💳",
    title: "Refund Requests",
    email: "refunds@disciplefy.in",
    description: "Subscription or payment issues and refund requests.",
  },
];

const socials = [
  { label: "Instagram", href: "https://instagram.com/disciplefy.app", icon: "📸" },
  { label: "YouTube", href: "https://youtube.com/@disciplefy", icon: "▶️" },
  { label: "Facebook", href: "https://facebook.com/disciplefy", icon: "👥" },
  { label: "WhatsApp", href: "https://whatsapp.com/channel/disciplefy", icon: "💬" },
];

export default function ContactPage() {
  return (
    <NextIntlClientProvider locale="en" messages={messages}>
      <Navbar />
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <h1 className="font-display font-extrabold text-4xl sm:text-5xl mb-4">Get in Touch</h1>
        <p className="text-[var(--muted)] text-lg mb-12">
          We&apos;d love to hear from you. Reach out through any of the channels below.
        </p>

        <section className="grid grid-cols-1 sm:grid-cols-2 gap-6 mb-16">
          {contacts.map((c) => (
            <div key={c.email} className="rounded-xl border border-[var(--border)] bg-[var(--surface)] p-6">
              <span className="text-2xl">{c.icon}</span>
              <h2 className="font-display font-bold text-lg mt-3 mb-1">{c.title}</h2>
              <a href={`mailto:${c.email}`} className="text-primary underline text-sm">{c.email}</a>
              <p className="text-[var(--muted)] text-sm mt-2 leading-relaxed">{c.description}</p>
            </div>
          ))}
        </section>

        <section className="mb-16">
          <h2 className="font-display font-bold text-2xl mb-4 text-primary">Follow Us</h2>
          <div className="flex gap-4">
            {socials.map((s) => (
              <a
                key={s.label}
                href={s.href}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={s.label}
                className="flex items-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-4 py-2 text-sm text-[var(--muted)] hover:text-[var(--text)] transition-colors"
              >
                <span className="text-lg">{s.icon}</span>
                {s.label}
              </a>
            ))}
          </div>
        </section>

        <section>
          <p className="text-sm text-[var(--muted)]">
            We typically respond within 2–3 business days.
          </p>
        </section>
      </main>
      <Footer />
    </NextIntlClientProvider>
  );
}
